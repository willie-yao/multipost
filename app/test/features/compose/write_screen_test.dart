import 'dart:async';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/design/caption_text.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  testWidgets(
    'shared writing accepts blank text and keeps own caption independent',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final initial = editOwnCaption(
        sampleDraft(),
        Destination.bluesky,
        'Own words',
        s.clock.now(),
      );
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
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
      await tester.enterText(find.byType(TextField), '');
      expect(c.draft.shared.text, '');
      expect(resolveContent(c.draft, Destination.bluesky).text, 'Own words');
      expect(find.text('Own caption'), findsOneWidget);
      await settleEditor(tester);
      expect(
        (await tester.runAsync(() => s.drafts.get(c.draft.id)))!.shared.text,
        '',
      );
    },
  );

  testWidgets(
    'native caption controller preserves composing selection across save rebuilds',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
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
      await tester.showKeyboard(find.byType(TextField));
      const value = TextEditingValue(
        text: 'composing',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 9),
      );
      tester.testTextInput.updateEditingValue(value);
      await settleEditor(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.value,
        value,
      );
      final field = tester.widget<CaptionEditor>(find.byType(CaptionEditor));
      c.change(editSharedCaption(c.draft, 'composing more', s.clock.now()));
      await tester.pump();
      expect(field.controller.selection, value.selection);
      expect(field.controller.value.composing, value.composing);
    },
  );

  testWidgets('Review advances only after the latest stage is durable', (
    tester,
  ) async {
    final s = await tester.runAsync(localTestServices);
    addTearDown(s!.close);
    final c = DraftController(sampleDraft(), s.drafts, s.clock);
    addTearDown(c.dispose);
    Draft? acknowledged;
    await tester.pumpWidget(
      CaptionApp(
        home: WriteScreen(
          controller: c,
          media: s.media,
          pickerImports: s.pickerImports,
          canLaunchPicker: true,
          onReview: () => acknowledged = c.draft,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Latest');
    await tester.tap(find.text('Review post'));
    await settleEditor(tester);
    expect(acknowledged!.stage, ComposeStage.review);
    expect(await tester.runAsync(() => s.drafts.get(c.draft.id)), acknowledged);
  });
  testWidgets(
    'shared composer exposes media above writing and scoped destination versions',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: WriteScreen(
            controller: c,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: false,
            onReview: () {},
          ),
        ),
      );
      expect(find.text('Add media'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Add media')).dy,
        lessThan(tester.getTopLeft(find.byType(TextField)).dy),
      );
      final mediaButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Add media'),
      );
      expect(mediaButton.onPressed, isNull);
      await tester.ensureVisible(find.text('Bluesky'));
      await tester.tap(find.text('Bluesky'));
      await settleEditor(tester);
      expect(find.text('Bluesky version'), findsOneWidget);
    },
  );
  testWidgets(
    'a failed Review stage save leaves writing active with its words',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final initial = sampleDraft().copyWith(stage: ComposeStage.write);
      await tester.runAsync(() => s.drafts.save(initial, expectedRevision: -1));
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: WriteScreen(
            controller: c,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
            onReview: () => fail('Review must not open'),
          ),
        ),
      );
      await settleEditor(tester);
      await tester.runAsync(
        () => s.database.db.execute(
          "CREATE TRIGGER reject_stage BEFORE UPDATE ON drafts BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        ),
      );
      await tester.tap(find.text('Review post'));
      await settleEditor(tester);
      expect(c.draft.stage, ComposeStage.write);
      expect(c.draft.shared.text, initial.shared.text);
      expect(c.saveState, SaveState.failed);
    },
  );
  testWidgets(
    'Change destinations stays guarded through its asynchronous stage save',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(sampleDraft(), s.drafts, s.clock);
      addTearDown(c.dispose);
      final release = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: WriteScreen(
            controller: c,
            media: s.media,
            pickerImports: s.pickerImports,
            canLaunchPicker: true,
            onReview: () {},
            onChangeDestinations: () async {
              calls++;
              await release.future;
            },
          ),
        ),
      );
      final button = find.widgetWithText(TextButton, 'Change');
      final queued = tester.widget<TextButton>(button).onPressed!;
      await tester.ensureVisible(button);
      await tester.tap(button);
      await settleEditor(tester);
      expect(calls, 1);
      final blocked = tester.widget<TextButton>(button).onPressed;
      queued();
      await settleEditor(tester);
      release.complete();
      await settleEditor(tester);
      expect(blocked, isNull);
      expect(calls, 1);
    },
  );
}
