import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fixtures/acceptance_services.dart';
import 'mixed_results_test.dart' show captureNativeMatrix;

// One prebuilt APK, six explicit launches separated by host-issued force-stop.
// A completed test proves a checkpoint; deliberately unresolved fixture futures
// keep the named real operation in flight until Android kills this process.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'R1 durable native interruption checkpoint (external force-stop required)',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final root = Directory(p.join(support.path, 'r1-native-recovery'));
      await root.create(recursive: true);
      final marker = File(p.join(root.path, 'phase.json'));
      final state = await marker.exists()
          ? jsonDecode(await marker.readAsString()) as Map<String, dynamic>
          : <String, dynamic>{'next': 0};
      final phase = state['next'] as int;
      if (phase > 5) {
        throw StateError(
          'Completed fixture retained. Inspect/clean only this R1 root before a new run.',
        );
      }
      final x = NativePublisher(Destination.x, PublishStatus.unknown);
      final app = await nativeFixture(
        root,
        providers: {Destination.x: x},
        mediaFactory: phase == 0 ? (db, path) => _HeldImport(db, path) : null,
      );
      Future<void> checkpoint(int next) async {
        state['next'] = next;
        await marker.writeAsString(jsonEncode(state), flush: true);
        debugPrint(
          'R1 CHECKPOINT phase=$phase next=$next; pid=$pid; root=${root.path}; force-stop before next launch',
        );
      }

      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: app)));
      await nativeSettle(tester);
      if (phase == 0) {
        await captureNativeMatrix(tester, binding, support);
        final attachments = <Attachment>[];
        for (var i = 0; i < 2; i++) {
          final source = await syntheticPhoto(root, i);
          final asset = await app.media.importFile(source);
          attachments.add(
            Attachment(
              assetId: asset.id,
              altText: 'Owned synthetic photo ${i + 1}',
            ),
          );
          await File(source.path).delete();
        }
        final draft = Draft(
          id: 'r1-kept-two-photo',
          updatedAt: app.clock.now(),
          stage: ComposeStage.review,
          selected: {Destination.instagram},
          shared: PostContent(
            text: 'Durable shared caption 🌻 日本語 العربية',
            media: attachments.reversed.toList(),
          ),
          versions: {
            Destination.instagram: DestinationVersion(
              ownText: 'Durable own caption 🌻 日本語 العربية',
            ),
          },
        );
        final controller = DraftController(draft, app.drafts, app.clock);
        expect(await controller.flush(), isTrue);
        expect(controller.saveState, SaveState.saved);
        controller.dispose();
        final reviewed = await app.review.review(draft, directOnline: true);
        expect(reviewed.canProceed, isTrue);
        final package = await app.instagram.prepare(
          reviewed.snapshot,
          operationId: 'r1-kept-package',
        );
        state['package'] = package.id;
        state['order'] = draft.shared.media.map((a) => a.assetId).toList();
        final operation = await app.pickerImports.begin(
          draftId: draft.id,
          draftRevision: draft.revision,
        );
        state['import'] = operation.id;
        final sources = [
          await syntheticPhoto(root, 10),
          await syntheticPhoto(root, 11),
        ];
        unawaited(app.pickerImports.complete(operation.id, sources));
        await (app.media as _HeldImport).started.future;
        final pending = (await app.pickerImports.unresolved())!;
        expect(pending.isComplete, isFalse);
        expect(pending.assets, hasLength(1));
        await checkpoint(1);
      } else {
        // Startup recovery changes local evidence only. No provider send is made.
        await app.attempts.recoverInterrupted();
        expect(x.sends, 0);
        final kept = (await app.drafts.get('r1-kept-two-photo'))!;
        expect(kept.revision, 0);
        expect(kept.stage, ComposeStage.review);
        expect(kept.shared.text, 'Durable shared caption 🌻 日本語 العربية');
        expect(
          kept.versions[Destination.instagram]!.ownText,
          'Durable own caption 🌻 日本語 العربية',
        );
        expect(
          kept.shared.media.map((a) => a.assetId).toList(),
          state['order'],
        );
        final package = (await app.instagramRepo.get(
          state['package'] as String,
        ))!;
        expect(
          package.photos.map((a) => a.assetId),
          kept.shared.media.map((a) => a.assetId),
        );
        for (final attachment in kept.shared.media) {
          final asset = (await app.media.find(attachment.assetId))!;
          final file = await app.media.fileFor(asset.id);
          expect(
            (await sha256.bind(file.openRead()).first).toString(),
            asset.sha256,
          );
        }
        for (final photo in package.photos) {
          await app.instagram.fileFor(package, photo);
        }
        expect(
          await File(p.join(root.path, 'synthetic-picker-0.png')).exists(),
          isFalse,
        );
        expect(
          await File(p.join(root.path, 'synthetic-picker-1.png')).exists(),
          isFalse,
        );
        if (phase == 1) {
          final pending = (await app.pickerImports.unresolved())!;
          expect(pending.id, state['import']);
          expect(pending.assets, hasLength(1));
          expect(pending.isComplete, isFalse);
          // Remove only synthetic picker sources; imported/private bytes survive.
          for (final i in [10, 11]) {
            await File(p.join(root.path, 'synthetic-picker-$i.png')).delete();
          }
          await app.pickerImports.cancel(pending.id);
          final held = _HeldSave(app.drafts);
          final controller = DraftController(kept, held, app.clock);
          expect(await controller.flush(), isTrue);
          controller.change(
            kept.copyWith(
              revision: 1,
              shared: PostContent(
                text: 'UNCOMMITTED must never be Saved',
                media: kept.shared.media,
              ),
            ),
          );
          unawaited(controller.flush());
          await held.started.future;
          expect(controller.saveState, SaveState.saving);
          expect(controller.savedRevision, 0);
          expect((await app.drafts.get(kept.id))!.revision, 0);
          await checkpoint(2);
        } else if (phase == 2) {
          expect(await app.pickerImports.unresolved(), isNull);
          final transfer = _HeldExport();
          final service = InstagramService(
            app.instagramRepo,
            app.media,
            app.instagramPackageRoot,
            app.instagramPolicy,
            app.ids,
            app.clock,
            transfer: transfer,
          );
          unawaited(service.saveMissingPhotos(package.id));
          await transfer.started.future;
          final jobs = await app.instagramRepo.exportJobs(package.id);
          expect(jobs, hasLength(2));
          expect(jobs.every((j) => !j.completed), isTrue);
          expect(
            (await app.instagramRepo.progress(package.id)).savedUris,
            isEmpty,
          );
          await checkpoint(3);
        } else if (phase == 3 || phase == 4) {
          final jobs = await app.instagramRepo.exportJobs(package.id);
          expect(jobs, hasLength(2));
          expect(jobs.every((j) => !j.completed), isTrue);
          if (phase == 4) {
            final before = (await app.attempts.effectiveAttempts(
              state['before'] as String,
            )).single;
            expect(before.outcome.status, PublishStatus.pending);
            expect(before.dispatchAt, isNull);
            expect(before.uploadState['synthetic-upload'], 'ready');
          }
          await connectNativeFixtures(app);
          final draft = kept.copyWith(
            id: phase == 3 ? 'r1-before' : 'r1-after',
            selected: {Destination.x},
            versions: {},
          );
          await app.drafts.save(draft, expectedRevision: -1);
          final reviewed = await app.review.review(draft, directOnline: true);
          expect(reviewed.canProceed, isTrue);
          final started = Completer<void>();
          x.onSend = (post, context) async {
            await context.saveUpload('synthetic-upload', 'ready');
            if (phase == 4) await context.markDispatch();
            started.complete();
            return Completer<PublishOutcome>().future;
          };
          unawaited(
            app.publishing.confirm(
              reviewed.snapshot,
              operationId: 'r1-phase-$phase',
            ),
          );
          await started.future;
          final group = (await app.attempts.getGroupForDraft(draft.id))!;
          state[phase == 3 ? 'before' : 'after'] = group.id;
          final attempt = (await app.attempts.effectiveAttempts(group.id))
              .single;
          expect(
            attempt.outcome.status,
            phase == 3 ? PublishStatus.preparing : PublishStatus.sending,
          );
          expect(attempt.dispatchAt != null, phase == 4);
          expect(x.sends, 1);
          await checkpoint(phase + 1);
        } else if (phase == 5) {
          final before = (await app.attempts.effectiveAttempts(
            state['before'] as String,
          )).single;
          final after = (await app.attempts.effectiveAttempts(
            state['after'] as String,
          )).single;
          expect(before.outcome.status, PublishStatus.pending);
          expect(before.dispatchAt, isNull);
          expect(after.outcome.status, PublishStatus.unknown);
          expect(after.outcome.reasonCode, 'interrupted-after-dispatch');
          expect(after.dispatchAt, isNotNull);
          expect(after.uploadState['synthetic-upload'], 'ready');
          expect(x.sends, 0);
          await checkpoint(6);
          await app.close();
        }
      }
      debugPrint(
        'R1 phase=$phase checkpoint assertions passed; in-flight work is NOT claimed completed. No live traffic/gallery writes.',
      );
    },
  );
}

class _HeldImport extends MediaFiles {
  _HeldImport(LocalDatabase db, Directory root) : super(db, root, const Ids());
  final started = Completer<void>();
  @override
  Future<MediaAsset> importOperationItem(
    XFile file, {
    required String operationId,
    required int ordinal,
    required String expectedSha256,
  }) {
    if (ordinal == 1) {
      started.complete();
      return Completer<MediaAsset>().future;
    }
    return super.importOperationItem(
      file,
      operationId: operationId,
      ordinal: ordinal,
      expectedSha256: expectedSha256,
    );
  }
}

class _HeldSave implements DraftRepository {
  _HeldSave(this.delegate);
  final DraftRepository delegate;
  final started = Completer<void>();
  @override
  Future<Draft?> get(String id) => delegate.get(id);
  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) {
    started.complete();
    return Completer<void>().future;
  }
}

class _HeldExport implements AndroidTransfer {
  final started = Completer<void>();
  @override
  Future<List<PhotoSaveResult>> savePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) {
    started.complete();
    return Completer<List<PhotoSaveResult>>().future;
  }

  @override
  Future<List<PhotoSaveResult>> reconcilePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) async => [];
  @override
  Future<void> copyCaption(String caption) async => throw UnimplementedError();
  @override
  Future<LaunchResult> openInstagram() async => throw UnimplementedError();
  @override
  Future<ShareDispatch> sharePhotos(InstagramPackage package) async =>
      throw UnimplementedError();
}
