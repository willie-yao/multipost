import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
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
    'native shared and own caption editors retain real text and independent media',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final root = Directory(p.join(support.path, 'l6-native-test'));
      if (await root.exists()) await root.delete(recursive: true);
      await root.create(recursive: true);
      final database = await LocalDatabase.open(
        databaseFactory,
        p.join(root.path, 'test.db'),
      );
      final media = MediaFiles(
        database,
        Directory(p.join(root.path, 'media')),
        const Ids(),
      );
      final services = AppServices(
        instagramPackageRoot: Directory(
          p.join(root.path, 'instagram-packages'),
        ),
        database: database,
        media: media,
        drafts: SqliteDraftRepository(database, media: media),
        accounts: LocalAccountRepository(database),
        clock: const Clock(),
        ids: const Ids(),
      );
      DraftController? controller;
      Future<void> capture(String name) async {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        await File(p.join(support.path, '$name.png'))
            .writeAsBytes(await binding.takeScreenshot(name));
      }

      try {
        await services.recoverPicker(ImagePicker());
        final attachments = <Attachment>[];
        for (var index = 0; index < 2; index++) {
          final image = img.Image(width: 320, height: 180);
          img.fill(
            image,
            color: index == 0
                ? img.ColorRgb8(0, 115, 145)
                : img.ColorRgb8(15, 70, 32),
          );
          img.fillCircle(
            image,
            x: index == 0 ? 120 : 200,
            y: 90,
            radius: 60,
            color: index == 0
                ? img.ColorRgb8(246, 199, 53)
                : img.ColorRgb8(43, 149, 77),
          );
          final file = File(p.join(root.path, 'synthetic-$index.png'));
          await file.writeAsBytes(img.encodePng(image));
          final asset = await media.importFile(XFile(file.path));
          attachments.add(
            Attachment(
              assetId: asset.id,
              altText: 'Synthetic test photo ${index + 1}',
            ),
          );
        }
        var draft = Draft(
          id: 'l6-native',
          updatedAt: services.clock.now(),
          stage: ComposeStage.write,
          selected: Destination.values.toSet(),
          shared: PostContent(
            text: "A little color from today's walk. The city always leaves something worth noticing.",
            media: attachments,
          ),
        );
        draft = editOwnCaption(
          draft,
          Destination.bluesky,
          'Poppies along the reservoir path. The city always leaves something worth noticing.',
          services.clock.now(),
        );
        draft = editSharedCaption(
          draft,
          draft.shared.text,
          services.clock.now(),
        );
        await services.drafts.save(draft, expectedRevision: -1);
        controller = DraftController(draft, services.drafts, services.clock);
        final c = controller;
        await tester.pumpWidget(
          CaptionApp(
            home: WriteScreen(
              controller: c,
              media: media,
              pickerImports: services.pickerImports,
              canLaunchPicker: services.pickerRecoveryReady,
              onReview: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        await binding.convertFlutterSurfaceToImage();
        await capture('l6-write-standard');
        await tester.ensureVisible(find.text('Bluesky'));
        await tester.tap(find.text('Bluesky'));
        await tester.pumpAndSettle();
        expect(find.text('Bluesky version'), findsOneWidget);
        await capture('l6-version-standard');
        await tester.showKeyboard(find.byType(TextField));
        await Future<void>.delayed(const Duration(milliseconds: 800));
        await tester.pumpAndSettle();
        debugPrint(
          'L6_NATIVE_KEYBOARD_READY inset=${tester.view.viewInsets.bottom}',
        );
        // The local harness can exercise real Android input/Back during this
        // bounded pause. No personal device, account or external action is used.
        await Future<void>.delayed(const Duration(seconds: 20));
        await tester.pumpAndSettle();
        expect(find.text('Bluesky version'), findsOneWidget);
        debugPrint(
          'L6_NATIVE_KEYBOARD_AFTER inset=${tester.view.viewInsets.bottom} caption=${c.draft.versions[Destination.bluesky]!.ownText}',
        );
        await capture('l6-version-after-keyboard');
        await tester.pumpWidget(
          CaptionApp(
            key: UniqueKey(),
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: VersionScreen(
                controller: c,
                destination: Destination.bluesky,
                media: media,
                pickerImports: services.pickerImports,
                canLaunchPicker: services.pickerRecoveryReady,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('l6-version-large');
        await tester.ensureVisible(find.text('Shared media'));
        expect(find.text('Done').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(
          CaptionApp(
            key: UniqueKey(),
            home: MediaQuery(
              data: MediaQueryData.fromView(tester.view)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: WriteScreen(
                controller: c,
                media: media,
                pickerImports: services.pickerImports,
                canLaunchPicker: services.pickerRecoveryReady,
                onReview: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture('l6-write-large');
        await tester.ensureVisible(find.text('Instagram'));
        expect(find.text('Review post').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(await c.flush(), isTrue);
        expect(
          (await services.drafts.get(draft.id))!.shared.media,
          attachments,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      } finally {
        controller?.dispose();
        await services.close();
        await root.delete(recursive: true);
      }
    },
  );
}
