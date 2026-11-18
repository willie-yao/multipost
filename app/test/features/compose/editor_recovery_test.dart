import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/compose/choose_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  for (final initialStage in [ComposeStage.write, ComposeStage.choose]) {
    final restoredStage = initialStage == ComposeStage.write
        ? ComposeStage.choose
        : ComposeStage.write;
    testWidgets(
      'confirmed conflict reload synchronizes host from ${initialStage.name} to ${restoredStage.name}',
      (tester) async {
        final s = await tester.runAsync(localTestServices);
        addTearDown(s!.close);
        final initial = sampleDraft().copyWith(stage: initialStage);
        await tester.runAsync(
          () => s.drafts.save(initial, expectedRevision: -1),
        );
        await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
        await settleEditor(tester);
        await tester.tap(find.text(initial.shared.text));
        await settleEditor(tester);
        final controller = initialStage == ComposeStage.write
            ? tester.widget<WriteScreen>(find.byType(WriteScreen)).controller
            : tester.widget<ChooseScreen>(find.byType(ChooseScreen)).controller;
        expect(controller.saveState, SaveState.saved);
        final competing = setStage(
          editSharedCaption(initial, 'Competing saved words', s.clock.now()),
          restoredStage,
          s.clock.now(),
        );
        await tester.runAsync(
          () => s.drafts.save(competing, expectedRevision: initial.revision),
        );
        controller.change(
          setStage(
            editSharedCaption(
              controller.draft,
              'Unsaved local words',
              s.clock.now(),
            ),
            restoredStage,
            s.clock.now(),
          ),
        );
        await tester.pump();
        final initialScreen = find.byType(
          initialStage == ComposeStage.choose ? ChooseScreen : WriteScreen,
        );
        expect(initialScreen, findsOneWidget);
        final save = controller.flush();
        await settleEditor(tester);
        expect(await save, isFalse);
        expect(initialScreen, findsOneWidget);
        await tester.tap(find.text('Reload saved draft'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Replace with saved copy'));
        await settleEditor(tester);
        expect(controller.draft.stage, restoredStage);
        expect(controller.draft.shared.text, competing.shared.text);
        expect(controller.saveState, SaveState.saved);
        expect(controller.savedRevision, competing.revision);
        expect(
          await tester.runAsync(() => s.drafts.get(initial.id)),
          controller.draft,
        );
        expect(
          find.byType(
            restoredStage == ComposeStage.choose ? ChooseScreen : WriteScreen,
          ),
          findsOneWidget,
        );
        expect(
          find.byType(
            initialStage == ComposeStage.choose ? ChooseScreen : WriteScreen,
          ),
          findsNothing,
        );
        expect(
          find.text(
            restoredStage == ComposeStage.choose
                ? 'Where should this go?'
                : 'Review post',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets(
    'conflict keeps labeled copy recovery until explicit reload confirmation',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final initial = editOwnCaption(
        sampleDraft(),
        Destination.bluesky,
        'My own words',
        s.clock.now(),
      );
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
      final flush1 = c.flush();
      await settleEditor(tester);
      await flush1;
      final competing = editSharedCaption(
        initial,
        'Saved elsewhere',
        s.clock.now(),
      );
      await tester.runAsync(
        () => s.drafts.save(competing, expectedRevision: initial.revision),
      );
      c.change(
        editSharedCaption(c.draft, 'Unsaved local words', s.clock.now()),
      );
      final flush2 = c.flush();
      await settleEditor(tester);
      await flush2;
      await tester.pumpWidget(
        CaptionApp(
          home: WriteScreen(
            controller: c,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
            onReview: () {},
          ),
        ),
      );
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.setData') {
              copied = (call.arguments as Map)['text'] as String;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.tap(find.text('Copy text'));
      await tester.pump();
      expect(copied, contains('Shared caption:\nUnsaved local words'));
      expect(copied, contains('Bluesky own caption:\nMy own words'));
      await tester.tap(find.text('Reload saved draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(c.draft.shared.text, 'Unsaved local words');
      await tester.tap(find.text('Reload saved draft'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Replace with saved copy'));
      await settleEditor(tester);
      expect(c.draft.shared.text, 'Saved elsewhere');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Saved elsewhere',
      );
    },
  );

  testWidgets(
    'Choose can explicitly repair multiple missing own-media targets without losing its controller',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final initial = await tester.runAsync(() async {
        var draft = sampleDraft().copyWith(selected: {Destination.instagram});
        for (final destination in [Destination.x, Destination.bluesky]) {
          final file = File(
            '${File(s.database.db.path).parent.path}/${destination.name}.png',
          );
          await file.writeAsBytes(
            img.encodePng(img.Image(width: 8, height: 6)),
          );
          final asset = await s.media.importFile(XFile(file.path));
          draft = editOwnMedia(draft, destination, [
            Attachment(assetId: asset.id),
          ], s.clock.now());
        }
        await s.drafts.save(draft, expectedRevision: -1);
        for (final version in draft.versions.values) {
          await (await s.media.fileFor(version.ownMedia!.single.assetId))
              .delete();
        }
        return draft;
      });
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
      await settleEditor(tester);
      await tester.tap(find.text(initial!.shared.text));
      await settleEditor(tester);
      await tester.tap(find.text('Continue to writing'));
      await settleEditor(tester);
      expect(find.text('Repair draft media'), findsOneWidget);
      await tester.ensureVisible(find.text('Repair draft media'));
      await tester.tap(find.text('Repair draft media'));
      await settleEditor(tester);
      expect(find.text('Done repairing'), findsOneWidget);
      for (final name in ['X', 'Bluesky']) {
        await tester.ensureVisible(find.text('$name · Not selected'));
        await tester.tap(find.text('$name · Not selected'));
        await settleEditor(tester);
        await tester.ensureVisible(find.text('Edit own media'));
        await tester.tap(find.text('Edit own media'));
        await settleEditor(tester);
        await tester.ensureVisible(find.text('Remove'));
        await tester.tap(find.text('Remove'));
        await settleEditor(tester);
        // Remove offers Undo in a snackbar; clear it before leaving.
        expect(find.text('Undo'), findsOneWidget);
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger).first)
            .removeCurrentSnackBar();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await settleEditor(tester);
        await tester.tap(find.text('Done'));
        await settleEditor(tester);
      }
      await tester.tap(find.text('Done repairing'));
      await settleEditor(tester);
      expect(find.text('Where should this go?'), findsOneWidget);
      final saved = await tester.runAsync(() => s.drafts.get(initial.id));
      expect(saved!.stage, ComposeStage.choose);
      expect(saved.selected, {Destination.instagram});
      expect(saved.shared.text, initial.shared.text);
      expect(saved.versions[Destination.x]!.ownMedia, isEmpty);
      expect(saved.versions[Destination.bluesky]!.ownMedia, isEmpty);
    },
  );
}
