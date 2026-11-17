import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/accounts/accounts_screen.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/media/media_editor_screen.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/review/review_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/app_fixture.dart';
import '../support/coordinator_fixture.dart';
import '../support/review_fixtures.dart' show photo;

void main() {
  for (final size in [const Size(320, 720), const Size(720, 320)]) {
    testWidgets(
      'Write, own versions, media, Review, Accounts and Results reflow at $size with 200 percent text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final h = (await tester.runAsync(() => coordinatorHarness()))!;
        addTearDown(h.close);
        final initial = (await tester.runAsync(() async {
          final original = (await h.app.drafts.get(h.review.draftId))!;
          final second = await photo(
            h.app.media.root,
            h.app.media.importFile,
            'second',
          );
          final next = original.copyWith(
            revision: 1,
            shared: original.shared.copyWith(
              media: [
                ...original.shared.media,
                Attachment(assetId: second.id),
              ],
            ),
            versions: {
              Destination.bluesky: DestinationVersion(
                ownText: 'Own words 🌻 日本語 العربية',
              ),
            },
          );
          await h.app.drafts.save(next, expectedRevision: 0);
          return next;
        }))!;
        final c = DraftController(initial, h.app.drafts, h.clock);
        addTearDown(c.dispose);
        final semantics = tester.ensureSemantics();
        try {
          Future<void> show(Widget screen) async {
            await tester.pumpWidget(CaptionApp(key: UniqueKey(), home: screen));
            if (screen is ReviewScreen) {
              await settleEditorUntil(tester, () {
                final action = find.widgetWithText(
                  FilledButton,
                  'Publish & prepare',
                );
                return action.evaluate().isNotEmpty &&
                    tester.widget<FilledButton>(action).onPressed != null;
              });
            } else {
              await settleEditor(tester);
            }
            expect(tester.takeException(), isNull);
          }

          await show(
            WriteScreen(
              controller: c,
              media: h.app.media,
              pickerImports: h.app.pickerImports,
              canLaunchPicker: true,
              onReview: () {},
            ),
          );
          final field = find.widgetWithText(TextField, 'Shared caption');
          await tester.ensureVisible(field);
          const words =
              'A continuous caption 🌻 日本語 العربية\nMore words without deleting user text.';
          await tester.enterText(field, words);
          const editing = TextEditingValue(
            text: words,
            selection: TextSelection.collapsed(offset: 10),
            composing: TextRange(start: 2, end: 10),
          );
          tester.testTextInput.updateEditingValue(editing);
          await tester.pump();
          expect(tester.widget<TextField>(field).controller!.value, editing);
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          expect(c.draft.shared.text, words);
          await tester.ensureVisible(find.text('Review post'));
          expect(find.text('Review post').hitTestable(), findsOneWidget);
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await show(
            VersionScreen(
              controller: c,
              destination: Destination.bluesky,
              media: h.app.media,
              pickerImports: h.app.pickerImports,
              canLaunchPicker: true,
            ),
          );
          await tester.ensureVisible(find.text('Compare captions'));
          await tester.tap(find.text('Compare captions'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Close comparison'));
          await tester.tap(find.text('Close comparison'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Shared caption'));
          await tester.tap(find.text('Shared caption'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Keep own caption'));
          await tester.tap(find.text('Keep own caption'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          expect(
            c.draft.versions[Destination.bluesky]!.ownText,
            'Own words 🌻 日本語 العربية',
          );
          await show(
            MediaEditorScreen(
              items: c.draft.shared.media,
              media: h.app.media,
              controller: c,
              pickerImports: h.app.pickerImports,
              canLaunchPicker: true,
              onChanged: (items) =>
                  c.change(editSharedMedia(c.draft, items, h.clock.now())),
            ),
          );
          final firstId = c.draft.shared.media.first.assetId;
          await tester.ensureVisible(find.byTooltip('Move media 1 later'));
          await tester.tap(find.byTooltip('Move media 1 later'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          expect(c.draft.shared.media.last.assetId, firstId);
          await tester.ensureVisible(find.text('Add description').first);
          await tester.tap(find.text('Add description').first);
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          await tester.enterText(
            find.widgetWithText(TextField, 'Media description'),
            'Description 🌻 日本語',
          );
          await tester.ensureVisible(find.text('Save description'));
          await tester.tap(find.text('Save description'));
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          expect(c.draft.shared.media.first.altText, 'Description 🌻 日本語');
          await tester.ensureVisible(find.text('Remove').last);
          await tester.tap(find.text('Remove').last);
          await settleEditor(tester);
          expect(tester.takeException(), isNull);
          expect(c.draft.shared.media, hasLength(1));
          await show(
            ReviewScreen(
              controller: c,
              service: h.reviewService,
              observeOnline: () async => true,
              onConfirm: (_) async {},
            ),
          );
          expect(find.text('Publish & prepare').hitTestable(), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Publish & prepare'),
                )
                .onPressed,
            isNotNull,
          );
          await tester.ensureVisible(find.text('Review again'));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await tester.runAsync(() async {
            await h.app.accounts.setState(
              Destination.x,
              AccountState.repairRequired,
            );
            await h.app.accounts.setState(
              Destination.bluesky,
              AccountState.removalPending,
            );
          });
          await show(AccountsScreen(accounts: h.app.accounts));
          await tester.ensureVisible(find.text('Removal pending'));
          expect(find.text('Removal pending').hitTestable(), findsOneWidget);
          await tester.runAsync(() async {
            await h.app.accounts.setState(
              Destination.x,
              AccountState.connected,
            );
            await h.app.accounts.setState(
              Destination.bluesky,
              AccountState.connected,
            );
          });
          final group = (await tester.runAsync(() async {
            final reviewed = await h.reviewDraft(c.draft);
            return h.coordinator.confirm(reviewed, operationId: 'acceptance');
          }))!;
          await show(
            ResultsScreen(
              groupId: group,
              attempts: h.attempts,
              coordinator: h.coordinator,
              instagram: h.app.instagramRepo,
            ),
          );
          await tester.ensureVisible(find.text('Finish in Instagram'));
          expect(
            find.text('Finish in Instagram').hitTestable(),
            findsOneWidget,
          );
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
