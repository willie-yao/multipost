import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/providers/provider.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/publish_coordinator.dart';
import 'package:cross_posting_app/features/publishing/publishing_boundary.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'P7 native synthetic partial and Unknown results with scoped reflow',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final parent = await Directory(p.join(support.path, 'p7-fixtures'))
          .create(recursive: true);
      final root = await parent.createTemp('results-');
      final database = await LocalDatabase.open(
        databaseFactory,
        p.join(root.path, 'fixture.db'),
      );
      final media = MediaFiles(
        database,
        Directory(p.join(root.path, 'media')),
        const Ids(),
      );
      final app = AppServices(
        database: database,
        media: media,
        drafts: SqliteDraftRepository(database, media: media),
        accounts: LocalAccountRepository(database),
        clock: const Clock(),
        ids: const Ids(),
        instagramPackageRoot: Directory(
          p.join(root.path, 'instagram-packages'),
        ),
      );
      final x = _SyntheticPublisher(Destination.x, PublishStatus.published);
      final bluesky = _SyntheticPublisher(
        Destination.bluesky,
        PublishStatus.notPublished,
      );
      final review = ReviewService(
        app.drafts,
        media,
        app.accounts,
        _SyntheticValidators(app),
        app.clock,
      );
      final coordinator = PublishCoordinator(
        attempts: app.attempts,
        review: review,
        instagram: app.instagram,
        providers: {Destination.x: x, Destination.bluesky: bluesky},
        directOnline: () => true,
      );
      for (final destination in [Destination.x, Destination.bluesky]) {
        await app.accounts.save(
          AccountView(
            destination: destination,
            state: AccountState.connected,
            capability: 'Synthetic fixture only',
            identity: AccountIdentity(
              destination: destination,
              subject: destination == Destination.x
                  ? '101'
                  : 'did:plc:abcdefghijklmnopqrstuvwx',
              handle: destination == Destination.x
                  ? '@synthetic'
                  : 'synthetic.bsky.social',
            ),
          ),
        );
      }
      final photo = img.Image(width: 720, height: 480);
      img.fill(photo, color: img.ColorRgb8(0, 105, 125));
      img.fillRect(
        photo,
        x1: 0,
        y1: 300,
        x2: 720,
        y2: 480,
        color: img.ColorRgb8(30, 75, 38),
      );
      final source = File(p.join(root.path, 'synthetic-owned-photo.png'));
      await source.writeAsBytes(img.encodePng(photo));
      final asset = await media.importFile(XFile(source.path));
      Future<String> makeGroup(String caption) async {
        final draft = Draft(
          id: app.ids.next(),
          updatedAt: app.clock.now(),
          selected: Destination.values.toSet(),
          shared: PostContent(
            text: caption,
            media: [
              Attachment(
                assetId: asset.id,
                altText: 'Synthetic color-block fixture',
              ),
            ],
          ),
          versions: {
            Destination.bluesky: DestinationVersion(
              ownText: '$caption My own Bluesky version.',
            ),
          },
        );
        await app.drafts.save(draft, expectedRevision: -1);
        final checked = await review.review(draft, directOnline: true);
        expect(checked.canProceed, isTrue);
        return coordinator.confirm(
          checked.snapshot,
          operationId: app.ids.next(),
        );
      }

      Future<void> waitFor(bool Function() condition) async {
        for (var i = 0; i < 160 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 25));
          await Future<void>.delayed(const Duration(milliseconds: 25));
        }
        await tester.pumpAndSettle();
        expect(
          condition(),
          isTrue,
          reason: 'Bounded native results wait expired',
        );
      }

      Widget screen(String id, {bool reflow = false}) {
        final results = ResultsScreen(
          key: ValueKey('$id:$reflow'),
          groupId: id,
          attempts: app.attempts,
          coordinator: coordinator,
          instagram: app.instagramRepo,
          onRetry: (_) async {},
          openExternal: (_, _) async => false,
        );
        return CaptionApp(
          home: reflow
              ? Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 320,
                    child: MediaQuery(
                      data: MediaQueryData.fromView(tester.view).copyWith(
                        size: const Size(320, 900),
                        textScaler: const TextScaler.linear(2),
                      ),
                      child: results,
                    ),
                  ),
                )
              : results,
        );
      }

      final partialId = await makeGroup(
        'Synthetic reviewed caption. Every destination keeps its own result.',
      );
      await tester.pumpWidget(screen(partialId));
      await waitFor(() => find.text('Retry Bluesky').evaluate().isNotEmpty);
      debugPrint(
        'P7 STABLE FULL FRAME: synthetic partial results; 15 second capture window',
      );
      await Future<void>.delayed(const Duration(seconds: 15));
      await binding.convertFlutterSurfaceToImage();
      Future<void> capture(String state) async {
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        await File(p.join(support.path, 'p7-$state.png'))
            .writeAsBytes(await binding.takeScreenshot('p7-$state'));
        debugPrint('P7 CAPTURE $state');
      }

      await capture('partial');
      await tester.ensureVisible(find.text('Retry Bluesky'));
      await capture('partial-actions');
      bluesky.status = PublishStatus.unknown;
      final unknownId = await makeGroup(
        'Synthetic Unknown response. Check before deciding what to do.',
      );
      await tester.pumpWidget(screen(unknownId));
      await waitFor(() => find.text('Check Bluesky').evaluate().isNotEmpty);
      await capture('unknown');
      await tester.ensureVisible(find.text('Check Bluesky'));
      await capture('unknown-actions');
      expect(find.text('Retry Bluesky'), findsNothing);
      final sends = bluesky.sends;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(bluesky.sends, sends);
      final online = await const PublishingBoundary().online();
      debugPrint(
        'P7 native point-in-time network availability=$online (not provider reachability)',
      );
      await tester.pumpWidget(screen(unknownId, reflow: true));
      await waitFor(() => find.text('Check Bluesky').evaluate().isNotEmpty);
      expect(tester.takeException(), isNull);
      await capture('320dp-200percent');
      await tester.ensureVisible(find.text('Check Bluesky'));
      await capture('320dp-200percent-actions');
      expect(tester.takeException(), isNull);
      expect(bluesky.sends, sends);
      await tester.pumpWidget(const SizedBox.shrink());
      await app.close();
      await root.delete(recursive: true);
      debugPrint(
        'P7 native synthetic checks passed; fixture removed; no live provider/browser/Instagram traffic.',
      );
    },
  );
}

class _SyntheticValidators implements ValidatorRegistry, DestinationValidator {
  _SyntheticValidators(this.app);
  final AppServices app;
  @override
  DestinationValidator forDestination(Destination destination) =>
      destination == Destination.instagram ? app.instagramPolicy : this;
  @override
  String get version => 'p7-synthetic-fixture-only-1';
  @override
  List<ReviewIssue> validate(ResolvedPost post) => [];
}

class _SyntheticPublisher implements PublishProvider {
  _SyntheticPublisher(this.destination, this.status);
  @override
  final Destination destination;
  PublishStatus status;
  int sends = 0;
  @override
  Future<PublishOutcome> send(ResolvedPost post, PublishContext context) async {
    sends++;
    if (status == PublishStatus.published || status == PublishStatus.unknown) {
      await context.markDispatch();
    }
    return PublishOutcome(
      status: status,
      source: status == PublishStatus.published
          ? EvidenceSource.provider
          : EvidenceSource.local,
      at: DateTime.now().toUtc(),
      remoteId: status == PublishStatus.published ? '1234567890' : null,
    );
  }

  @override
  Future<PublishOutcome> check(
    ResolvedPost post,
    PublishOutcome previous,
    PublishContext context,
  ) async => previous;
}
