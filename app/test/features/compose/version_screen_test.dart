import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  testWidgets(
    'a destination editor announces own caption without changing shared',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: VersionScreen(
            controller: c,
            destination: Destination.bluesky,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
          ),
        ),
      );
      await tester.tap(find.text('Own caption'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Bluesky words');
      expect(
        resolveContent(c.draft, Destination.bluesky).text,
        'Bluesky words',
      );
      expect(c.draft.shared.text, sampleDraft().shared.text);
      expect(find.text('Use shared photos'), findsOneWidget);
      await settleEditor(tester);
      expect(find.text('Saved on this device'), findsOneWidget);
    },
  );

  testWidgets(
    'caption reset cancel confirm and Undo preserve independent media edits',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(
        editOwnCaption(
          sampleDraft(),
          Destination.bluesky,
          'Own words',
          s.clock.now(),
        ),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: VersionScreen(
            controller: c,
            destination: Destination.bluesky,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
          ),
        ),
      );
      await tester.tap(find.text('Shared caption'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep own caption'));
      await tester.pumpAndSettle();
      expect(c.draft.versions[Destination.bluesky]!.ownText, 'Own words');
      await tester.tap(find.text('Shared caption'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use shared caption'));
      await tester.pumpAndSettle();
      expect(c.draft.versions[Destination.bluesky]!.ownText, isNull);
      c.change(editOwnMedia(c.draft, Destination.bluesky, [], s.clock.now()));
      await tester.pump();
      await tester.tap(find.text('Undo caption reset'));
      await tester.pump();
      expect(c.draft.versions[Destination.bluesky]!.ownText, 'Own words');
      expect(c.draft.versions[Destination.bluesky]!.ownMedia, isEmpty);
      await settleEditor(tester);
    },
  );

  testWidgets(
    'new caption edits invalidate old Undo without overwriting words',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(
        editOwnCaption(
          sampleDraft(),
          Destination.bluesky,
          'Own words',
          s.clock.now(),
        ),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: VersionScreen(
            controller: c,
            destination: Destination.bluesky,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
          ),
        ),
      );
      await tester.tap(find.text('Shared caption'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use shared caption'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Own caption'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Newer words');
      expect(find.text('Undo caption reset'), findsNothing);
      expect(c.draft.versions[Destination.bluesky]!.ownText, 'Newer words');
      await settleEditor(tester);
    },
  );
  testWidgets(
    'own media switches independently and exposes destination media controls',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: VersionScreen(
            controller: c,
            destination: Destination.bluesky,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
          ),
        ),
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(c.draft.versions[Destination.bluesky]!.ownMedia, isEmpty);
      expect(c.draft.versions[Destination.bluesky]!.ownText, isNull);
      expect(find.text('Edit own media'), findsOneWidget);
      expect(find.text('Add media'), findsOneWidget);
    },
  );
  testWidgets(
    'media reset Undo preserves newer caption and unchanged media needs no discard prompt',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(
        editOwnMedia(sampleDraft(), Destination.bluesky, [], s.clock.now()),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: VersionScreen(
            controller: c,
            destination: Destination.bluesky,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
          ),
        ),
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(find.text('Keep own media'), findsNothing);
      expect(c.draft.versions[Destination.bluesky]!.ownMedia, isNull);
      c.change(
        editOwnCaption(
          c.draft,
          Destination.bluesky,
          'New caption during media reset',
          s.clock.now(),
        ),
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Undo media reset'));
      await tester.tap(find.text('Undo media reset'));
      await tester.pump();
      expect(c.draft.versions[Destination.bluesky]!.ownMedia, isEmpty);
      expect(
        c.draft.versions[Destination.bluesky]!.ownText,
        'New caption during media reset',
      );
      await settleEditor(tester);
    },
  );
}
