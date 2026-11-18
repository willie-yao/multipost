import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/media/media_editor_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  testWidgets(
    'media reorder buttons and descriptions edit only the destination attachment version',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final assets = await tester.runAsync(() async {
        final result = <MediaAsset>[];
        for (var i = 0; i < 2; i++) {
          final file = File(
            '${File(s.database.db.path).parent.path}/photo-$i.png',
          );
          await file.writeAsBytes(
            img.encodePng(img.Image(width: 8, height: 6)),
          );
          result.add(await s.media.importFile(XFile(file.path)));
        }
        return result;
      });
      final shared = assets!.map((a) => Attachment(assetId: a.id)).toList();
      final initial = editOwnMedia(
        editSharedMedia(sampleDraft(), shared, s.clock.now()),
        Destination.bluesky,
        shared,
        s.clock.now(),
      );
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaEditorScreen(
            items: shared,
            media: s.media,
            controller: c,
            destination: Destination.bluesky,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
            onChanged: (items) => c.change(
              editOwnMedia(c.draft, Destination.bluesky, items, s.clock.now()),
            ),
          ),
        ),
      );
      await settleEditor(tester);
      expect(find.byTooltip('Move media 1 earlier'), findsOneWidget);
      await tester.tap(find.byTooltip('Move media 1 later'));
      await tester.pump();
      expect(
        c.draft.versions[Destination.bluesky]!.ownMedia!.first.assetId,
        shared.last.assetId,
      );
      await tester.tap(find.text('Add description').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Media description'),
        'A green fern',
      );
      await tester.tap(find.text('Save description'));
      await settleEditor(tester);
      expect(
        c.draft.versions[Destination.bluesky]!.ownMedia!.first.altText,
        'A green fern',
      );
      expect(c.draft.shared.media, shared);
      expect(c.draft.versions[Destination.bluesky]!.ownText, isNull);
      expect(c.saveState, SaveState.saved, reason: '${c.lastError}');
      final stored = await tester.runAsync(() => s.drafts.get(c.draft.id));
      expect(
        stored!.versions[Destination.bluesky]!.ownMedia!.first.altText,
        'A green fern',
      );
    },
  );
  testWidgets(
    'confirmed crop and rotation create owned copies while retaining original and description',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final original = await tester.runAsync(() async {
        final file = File(
          '${File(s.database.db.path).parent.path}/transform.png',
        );
        await file.writeAsBytes(img.encodePng(img.Image(width: 8, height: 6)));
        return s.media.importFile(XFile(file.path));
      });
      final initial = editSharedMedia(sampleDraft(), [
        Attachment(assetId: original!.id, altText: 'Keep my description'),
      ], s.clock.now());
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaEditorScreen(
            items: initial.shared.media,
            media: s.media,
            controller: c,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
            onChanged: (items) =>
                c.change(editSharedMedia(c.draft, items, s.clock.now())),
          ),
        ),
      );
      await settleEditor(tester);
      // Replace, Rotate and Crop live in the item's More menu.
      await tester.tap(find.byTooltip('More for media 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crop'));
      await settleEditor(tester);
      expect(find.text('Result preview'), findsOneWidget);
      expect(c.draft.shared.media.single.assetId, original.id);
      await tester.tap(find.text('Save crop'));
      await settleEditorUntil(
        tester,
        () => c.draft.shared.media.single.assetId != original.id,
      );
      final cropped = c.draft.shared.media.single;
      expect(cropped.assetId, isNot(original.id));
      expect(cropped.altText, 'Keep my description');
      final cropAsset = await tester.runAsync(
        () => s.media.find(cropped.assetId),
      );
      expect(cropAsset!.width, 6);
      expect(cropAsset.height, 6);
      // Replace, Rotate and Crop live in the item's More menu.
      await tester.tap(find.byTooltip('More for media 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rotate'));
      await settleEditor(tester);
      expect(c.draft.shared.media.single.assetId, cropped.assetId);
      await tester.tap(find.text('Save rotation'));
      await settleEditorUntil(
        tester,
        () => c.draft.shared.media.single.assetId != cropped.assetId,
      );
      expect(c.draft.shared.media.single.assetId, isNot(cropped.assetId));
      expect(
        await tester.runAsync(
          () async => (await s.media.fileFor(original.id)).exists(),
        ),
        isTrue,
      );
      expect(c.draft.shared.media.single.altText, 'Keep my description');
    },
  );
}
