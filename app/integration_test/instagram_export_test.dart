import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/instagram/android_transfer.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment('I2_PHASE', defaultValue: 'normal');
  testWidgets('native gallery fallback $phase (synthetic only)', (
    tester,
  ) async {
    final support = await getApplicationSupportDirectory();
    final database = await LocalDatabase.open(
      databaseFactory,
      p.join(support.path, 'i2-export-test.db'),
    );
    final media = MediaFiles(
      database,
      Directory(p.join(support.path, 'i2-export-test-media')),
      const Ids(),
    );
    final services = AppServices(
      database: database,
      media: media,
      drafts: SqliteDraftRepository(database, media: media),
      accounts: LocalAccountRepository(database),
      clock: const Clock(),
      ids: const Ids(),
      instagramPackageRoot: Directory(
        p.join(support.path, 'instagram-packages'),
      ),
    );
    addTearDown(services.close);
    final operation = phase.startsWith('gap')
        ? 'i2-native-gap-v1'
        : 'i2-native-${DateTime.now().microsecondsSinceEpoch}';
    InstagramPackage? package = await services.instagramRepo.findByOperation(
      operation,
    );
    if (package == null) {
      expect(
        phase,
        isNot('gap-recover'),
        reason: 'Paired write phase must persist through --no-uninstall.',
      );
      final attachments = <Attachment>[];
      for (var ordinal = 1; ordinal <= 2; ordinal++) {
        final image = img.Image(width: 400, height: 300);
        img.fill(image, color: img.ColorRgb8(ordinal == 1 ? 30 : 170, 90, 140));
        img.drawString(
          image,
          'PHOTO $ordinal',
          font: img.arial48,
          x: 45,
          y: 120,
          color: img.ColorRgb8(255, 255, 255),
        );
        final source = File(p.join(support.path, 'i2-number-$ordinal.png'));
        await source.writeAsBytes(img.encodePng(image), flush: true);
        final asset = await media.importFile(XFile(source.path));
        attachments.add(
          Attachment(
            assetId: asset.id,
            altText: 'Synthetic numbered photo $ordinal',
          ),
        );
      }
      final draft = Draft(
        id: services.ids.next(),
        updatedAt: services.clock.now(),
        selected: {Destination.instagram},
        shared: PostContent(
          text: 'Synthetic Caption gallery check. No publishing.',
          media: attachments,
        ),
      );
      await services.drafts.save(draft, expectedRevision: -1);
      package = await services.instagram.prepare(
        (await services.review.review(draft)).snapshot,
        operationId: operation,
      );
    }
    final frozen = package;
    if (phase == 'gap-write') {
      final jobs = [
        for (final photo in frozen.photos)
          await services.instagramRepo.ensureExportJob(
            frozen.id,
            photo.ordinal,
            services.ids.next(),
          ),
      ];
      for (final photo in frozen.photos) {
        await services.instagram.fileFor(frozen, photo);
      }
      final results = await services.instagram.transfer.savePhotos(
        frozen,
        jobs,
      );
      expect(
        results.every((r) => r.succeeded),
        isTrue,
        reason: results
            .map((r) => '${r.ordinal}:${r.errorCode}:${r.uri}')
            .join(', '),
      );
      expect(
        (await services.instagramRepo.progress(frozen.id)).savedUris,
        isEmpty,
      );
      debugPrint(
        'I2 GAP WRITTEN package=${frozen.id} uris=${results.map((r) => r.uri).toList()}',
      );
      return;
    }
    if (phase == 'gap-recover') {
      expect(
        (await services.instagramRepo.progress(frozen.id)).savedUris,
        isEmpty,
      );
      final recovered = await services.instagram.recheckSavedPhotos(frozen.id);
      expect(recovered.savedUris, hasLength(2));
      expect(await services.instagram.saveMissingPhotos(frozen.id), isEmpty);
      debugPrint(
        'I2 GAP RECOVERED package=${frozen.id} uris=${recovered.savedUris}',
      );
      return;
    }
    if (phase == 'gap-pending-complete') {
      final before = await services.instagramRepo.progress(frozen.id);
      final after = await services.instagram.recheckSavedPhotos(frozen.id);
      expect(after.savedUris, before.savedUris);
      expect(after.savedUris, hasLength(2));
      debugPrint('I2 PENDING COMPLETE uris=${after.savedUris}');
      return;
    }
    if (phase == 'gap-incomplete' || phase == 'gap-deleted') {
      final before = await services.instagramRepo.progress(frozen.id);
      expect(before.savedUris, hasLength(2));
      final checked = await services.instagram.recheckSavedPhotos(frozen.id);
      expect(
        checked.savedUris,
        hasLength(1),
      ); // Reconciliation does not recopy.
      final results = await services.instagram.saveMissingPhotos(frozen.id);
      expect(results, hasLength(1));
      expect(results.single.succeeded, isTrue);
      final after = await services.instagram.recheckSavedPhotos(frozen.id);
      expect(after.savedUris, hasLength(2));
      for (final entry in checked.savedUris.entries) {
        expect(after.savedUris[entry.key], entry.value);
      }
      debugPrint(
        'I2 $phase checked=${checked.savedUris} restored=${after.savedUris}',
      );
      return;
    }
    await services.instagram.copyCaption(
      frozen.id,
    ); // Write only; never reads clipboard.
    final results = await services.instagram.saveMissingPhotos(frozen.id);
    expect(results, hasLength(2));
    expect(
      results.every((r) => r.succeeded),
      isTrue,
      reason: results
          .map((r) => '${r.ordinal}:${r.errorCode}:${r.uri}')
          .join(', '),
    );
    final before = await services.instagram.recheckSavedPhotos(frozen.id);
    expect(before.savedUris, hasLength(2));
    expect(await services.instagram.saveMissingPhotos(frozen.id), isEmpty);
    expect(
      (await services.instagram.recheckSavedPhotos(frozen.id)).savedUris,
      before.savedUris,
    );
    final job = (await services.instagramRepo.exportJobs(frozen.id)).first;
    final source = await services.instagram.fileFor(
      frozen,
      frozen.photos.first,
    );
    final args = <String, Object>{
      'jobId': job.id,
      'sourcePath': source.path,
      'displayName': 'caption-${job.id}-01.png',
      'mimeType': 'image/png',
      'expectedHash': frozen.photos.first.sha256,
    };
    await expectLater(
      MethodChannelAndroidTransfer.channel.invokeMethod<Object>('savePhoto', {
        ...args,
        'sourcePath': p.join(support.path, 'i2-number-1.png'),
      }),
      throwsA(isA<PlatformException>()),
    );
    await expectLater(
      MethodChannelAndroidTransfer.channel.invokeMethod<Object>('savePhoto', {
        ...args,
        'displayName': '../escape.png',
      }),
      throwsA(isA<PlatformException>()),
    );
    await tester.pumpWidget(
      CaptionApp(
        home: InstagramScreen(package: frozen, service: services.instagram),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 of 2 saved'), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await File(p.join(support.path, 'i2-export-normal.png'))
        .writeAsBytes(await binding.takeScreenshot('i2-export-normal'));
    debugPrint('I2 NORMAL package=${frozen.id} uris=${before.savedUris}');
  });
}
