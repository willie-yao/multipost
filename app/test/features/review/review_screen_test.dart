import 'dart:async';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/design/caption_text.dart';
import 'package:cross_posting_app/features/compose/version_screen.dart';
import 'package:cross_posting_app/features/compose/write_screen.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/review/review_screen.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';
import '../../support/review_fixtures.dart';

void main() {
  setUp(() {
    WidgetController.hitTestWarningShouldBeFatal = true;
  });
  testWidgets(
    'review separates preparation and publishing and never confirms',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(
        editOwnCaption(
          sampleDraft(),
          Destination.bluesky,
          'My own version',
          s.clock.now(),
        ),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      var confirms = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: c,
            service: ReviewService(
              s.drafts,
              s.media,
              s.accounts,
              const LocalValidators(),
              s.clock,
            ),
            onConfirm: (_) async {
              confirms++;
            },
          ),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Publish now'), findsOneWidget);
      expect(find.text('Prepare only'), findsOneWidget);
      expect(find.text('Shared caption'), findsNWidgets(2));
      expect(find.text('Own caption'), findsOneWidget);
      expect(find.text('Approximate preview'), findsNWidgets(3));
      expect(find.text('Preparation setup required'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Publish & prepare'),
      );
      expect(button.onPressed, isNull);
      await tester.tap(find.text('Publish & prepare'));
      await tester.pump();
      expect(confirms, 0);
    },
  );

  testWidgets(
    'explicit Leave out changes only that selection and rebuilds review',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final initial = sampleDraft().copyWith(
        versions: {
          Destination.bluesky: DestinationVersion(ownText: 'Keep my own words'),
        },
      );
      final c = DraftController(initial, s.drafts, s.clock);
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: c,
            service: ReviewService(
              s.drafts,
              s.media,
              s.accounts,
              const LocalValidators(),
              s.clock,
            ),
            onConfirm: (_) async {},
          ),
        ),
      );
      await settleEditor(tester);
      expect(c.draft.selected.length, 3);
      final leave = find.text('Leave Bluesky out');
      await tester.ensureVisible(leave);
      await tester.tap(leave);
      await settleEditor(tester);
      expect(c.draft.selected, {Destination.x, Destination.instagram});
      expect(
        c.draft.versions[Destination.bluesky]!.ownText,
        'Keep my own words',
      );
      expect(find.byKey(const ValueKey('review-bluesky')), findsNothing);
      expect(
        (await tester.runAsync(() => s.drafts.get(c.draft.id)))!.selected,
        {Destination.x, Destination.instagram},
      );
    },
  );

  testWidgets('no destination and failed save keep final action blocked', (
    tester,
  ) async {
    final s = await tester.runAsync(localTestServices);
    addTearDown(s!.close);
    final initial = sampleDraft().copyWith(selected: {});
    await tester.runAsync(() => s.drafts.save(initial, expectedRevision: -1));
    final c = DraftController(initial, s.drafts, s.clock);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      CaptionApp(
        home: ReviewScreen(
          controller: c,
          service: ReviewService(
            s.drafts,
            s.media,
            s.accounts,
            const LocalValidators(),
            s.clock,
          ),
          onConfirm: (_) async {},
        ),
      ),
    );
    await settleEditor(tester);
    expect(
      find.text('Choose at least one destination before continuing.'),
      findsOneWidget,
    );
    await tester.runAsync(
      () => s.drafts.save(
        editSharedCaption(initial, 'competing', s.clock.now()),
        expectedRevision: 0,
      ),
    );
    c.change(editSharedCaption(c.draft, 'Keep unsaved words', s.clock.now()));
    await settleEditor(tester);
    expect(c.saveState, SaveState.failed);
    expect(find.text('Save this draft before reviewing.'), findsOneWidget);
    expect(find.text('Keep unsaved words'), findsWidgets);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );
  });

  testWidgets(
    'stale async review never displays old content and connectivity never confirms',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final gate = Completer<void>();
      final accounts = DelayedAccounts(gate.future);
      final c = DraftController(
        sampleDraft().copyWith(selected: {Destination.x}),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      final online = ValueNotifier<bool?>(false);
      addTearDown(online.dispose);
      var confirms = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: c,
            service: ReviewService(
              s.drafts,
              s.media,
              accounts,
              TestValidators(),
              s.clock,
            ),
            directOnline: online,
            onConfirm: (_) async {
              confirms++;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      c.change(editSharedCaption(c.draft, 'Newest words', s.clock.now()));
      gate.complete();
      await settleEditor(tester);
      expect(find.text('This post changed. Review it again.'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CaptionText && w.text == sampleDraft().shared.text,
        ),
        findsNothing,
      );
      online.value = true;
      await settleEditor(tester);
      expect(confirms, 0);
      expect(find.text('Preparation setup required'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CaptionText && w.text == 'Newest words',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('Instagram video repair is scoped and retains shared video', (
    tester,
  ) async {
    final s = await tester.runAsync(localTestServices);
    addTearDown(s!.close);
    final video = await tester.runAsync(
      () => syntheticVideo(s.media.root, s.database.db.insert),
    );
    final c = DraftController(
      sampleDraft().copyWith(
        shared: PostContent(
          text: 'video words',
          media: [Attachment(assetId: video!.id, altText: 'A moving scene')],
        ),
      ),
      s.drafts,
      s.clock,
    );
    addTearDown(c.dispose);
    Destination? edited;
    await tester.pumpWidget(
      CaptionApp(
        home: ReviewScreen(
          controller: c,
          service: ReviewService(
            s.drafts,
            s.media,
            s.accounts,
            const LocalValidators(),
            s.clock,
          ),
          onEdit: (d) async {
            edited = d;
          },
          onConfirm: (_) async {},
        ),
      ),
    );
    await settleEditorUntil(
      tester,
      () => find.text('Choose own photos for Instagram').evaluate().isNotEmpty,
    );
    final photos = find.text('Choose own photos for Instagram');
    await tester.ensureVisible(photos);
    await tester.tap(photos);
    await tester.pump();
    await settleEditorUntil(
      tester,
      () =>
          find.text('Choose own photos for Instagram').evaluate().isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    expect(edited, Destination.instagram);
    expect(c.draft.shared.media.single.assetId, video.id);
    expect(c.draft.selected.contains(Destination.instagram), isTrue);
    expect(find.text('A moving scene'), findsNWidgets(3));
  });

  testWidgets(
    'expired account reconnect waits for save and refreshes identities',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final accounts = ReviewAccounts()..expired = true;
      final c = DraftController(
        sampleDraft().copyWith(selected: {Destination.bluesky}),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      final online = ValueNotifier<bool?>(true);
      addTearDown(online.dispose);
      var opened = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: c,
            service: ReviewService(
              s.drafts,
              s.media,
              accounts,
              TestValidators(),
              s.clock,
            ),
            directOnline: online,
            onManageAccounts: () async {
              expect(c.savedRevision, c.draft.revision);
              opened++;
              accounts.expired = false;
              accounts.subject = 'new-identity';
            },
            onConfirm: (_) async {},
          ),
        ),
      );
      await settleEditor(tester);
      expect(find.text('@person'), findsOneWidget);
      await tester.ensureVisible(find.text('Reconnect'));
      await tester.tap(find.text('Reconnect'));
      await settleEditor(tester);
      expect(opened, 1);
      expect(find.textContaining('Connection expired.'), findsNothing);
      expect(c.draft.selected, {Destination.bluesky});
    },
  );

  testWidgets(
    '200 percent at 320dp expands complete caption without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final long = List.filled(25, 'Full words stay available.').join(' ');
      final c = DraftController(
        sampleDraft().copyWith(
          selected: {Destination.x},
          shared: PostContent(text: long),
        ),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(
        CaptionApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ReviewScreen(
              controller: c,
              service: ReviewService(
                s.drafts,
                s.media,
                s.accounts,
                const LocalValidators(),
                s.clock,
              ),
              onConfirm: (_) async {},
            ),
          ),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Show full caption'));
      await tester.tap(find.text('Show full caption'));
      await tester.pumpAndSettle();
      final caption = tester.widget<CaptionText>(find.byType(CaptionText));
      expect(caption.text, long);
      expect(caption.maxLines, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'review waits for account action and guards system Back and duplicate taps',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final c = DraftController(
        sampleDraft().copyWith(selected: {Destination.x}),
        s.drafts,
        s.clock,
      );
      addTearDown(c.dispose);
      final release = Completer<void>();
      var opened = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ReviewScreen(
                    controller: c,
                    service: ReviewService(
                      s.drafts,
                      s.media,
                      s.accounts,
                      const LocalValidators(),
                      s.clock,
                    ),
                    onManageAccounts: () async {
                      opened++;
                      await release.future;
                    },
                    onConfirm: (_) async =>
                        fail('Review must never confirm in L7'),
                  ),
                ),
              ),
              child: const Text('Open review'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open review'));
      await settleEditor(tester);
      final manage = find.widgetWithText(TextButton, 'Manage accounts');
      final queued = tester.widget<TextButton>(manage).onPressed!;
      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pump();
      queued();
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(opened, 1);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(tester.widget<TextButton>(manage).onPressed, isNull);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Back to library',
              ),
            )
            .onPressed,
        isNull,
      );
      release.complete();
      await settleEditor(tester);
      await tester.ensureVisible(find.byTooltip('Back to library'));
      await tester.tap(find.byTooltip('Back to library'));
      await settleEditor(tester);
      expect(find.text('Open review'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'host Instagram own-photo edit and explicit omission preserve shared video',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final video = await tester.runAsync(
        () => syntheticVideo(s.media.root, s.database.db.insert),
      );
      final ownPhoto = await tester.runAsync(
        () => photo(s.media.root, s.media.importFile, 'own-photo'),
      );
      final d = sampleDraft().copyWith(
        stage: ComposeStage.review,
        selected: {Destination.x, Destination.instagram},
        shared: PostContent(
          text: 'Keep shared video',
          media: [Attachment(assetId: video!.id, altText: 'shared movement')],
        ),
      );
      await tester.runAsync(() => s.drafts.save(d, expectedRevision: -1));
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
      await settleEditor(tester);
      await tester.tap(find.text('Keep shared video'));
      await tester.pump();
      await settleEditorUntil(
        tester,
        () =>
            find.text('Choose own photos for Instagram').evaluate().isNotEmpty,
      );
      final review = tester.widget<ReviewScreen>(find.byType(ReviewScreen));
      await tester.ensureVisible(find.text('Choose own photos for Instagram'));
      await tester.tap(find.text('Choose own photos for Instagram'));
      await tester.pump();
      await settleEditorUntil(
        tester,
        () => find.byType(VersionScreen).evaluate().isNotEmpty,
      );
      final version = tester.widget<VersionScreen>(find.byType(VersionScreen));
      expect(identical(version.controller, review.controller), isTrue);
      expect(version.destination, Destination.instagram);
      // L6 owns the native picker; inject its completed immutable local result here.
      version.controller.change(
        editOwnMedia(version.controller.draft, Destination.instagram, [
          Attachment(assetId: ownPhoto!.id, altText: 'own still photo'),
        ], s.clock.now()),
      );
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pump();
      await settleEditorUntil(
        tester,
        () =>
            find.text('own still photo').evaluate().isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(find.text('Choose own photos for Instagram'), findsNothing);
      expect(find.text('Own media'), findsOneWidget);
      expect(review.controller.draft.shared.media.single.assetId, video.id);
      await tester.ensureVisible(find.text('Leave Instagram out'));
      await tester.tap(find.text('Leave Instagram out'));
      await tester.pump();
      await settleEditorUntil(
        tester,
        () =>
            find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byKey(const ValueKey('review-x')).evaluate().isNotEmpty,
      );
      final saved = await tester.runAsync(() => s.drafts.get(d.id));
      expect(saved!.selected, {Destination.x});
      expect(saved.shared.media.single.assetId, video.id);
      expect(
        saved.versions[Destination.instagram]!.ownMedia!.single.assetId,
        ownPhoto.id,
      );
      expect(find.widgetWithText(FilledButton, 'Publish to X'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'shared Edit discovers missing deselected media and enters guarded repair once',
    (tester) async {
      final s = await tester.runAsync(localTestServices);
      addTearDown(s!.close);
      final asset = await tester.runAsync(
        () => photo(s.media.root, s.media.importFile, 'missing'),
      );
      final d = sampleDraft().copyWith(
        stage: ComposeStage.review,
        selected: {Destination.instagram},
        shared: PostContent(text: 'Repair from Review'),
        versions: {
          Destination.x: DestinationVersion(
            ownMedia: [Attachment(assetId: asset!.id)],
          ),
        },
      );
      await tester.runAsync(() async {
        await s.drafts.save(d, expectedRevision: -1);
        await (await s.media.fileFor(asset.id)).delete();
      });
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
      await settleEditor(tester);
      await tester.tap(find.text('Repair from Review'));
      await settleEditor(tester);
      final c = tester
          .widget<ReviewScreen>(find.byType(ReviewScreen))
          .controller;
      await tester.ensureVisible(find.text('Edit shared caption'));
      await tester.tap(find.text('Edit shared caption'));
      await settleEditor(tester);
      expect(find.text('Done repairing'), findsOneWidget);
      final repair = tester.widget<WriteScreen>(find.byType(WriteScreen));
      expect(identical(repair.controller, c), isTrue);
      expect(c.draft.stage, ComposeStage.review);
      expect(c.draft.selected, {Destination.instagram});
      expect(c.saveState, SaveState.failed);
      await tester.tap(find.text('Done repairing'));
      await settleEditor(tester);
      expect(find.byType(ReviewScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settleEditor(tester);
      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(c.saveState, SaveState.failed);
      expect(
        c.draft.versions[Destination.x]!.ownMedia!.single.assetId,
        asset.id,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('cold library flow restores own content and Review never sends', (
    tester,
  ) async {
    final s = await tester.runAsync(localTestServices);
    addTearDown(s!.close);
    await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s)));
    await settleEditor(tester);
    await tester.tap(find.text('Create a draft'));
    await settleEditor(tester);
    await tester.tap(find.byKey(const ValueKey('choose-bluesky')));
    await tester.pump();
    await tester.tap(find.text('Continue to writing'));
    await settleEditor(tester);
    expect(find.byType(WriteScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Restored shared words');
    await settleEditor(tester);
    await tester.tap(find.byTooltip('Back to library'));
    await settleEditor(tester);
    await tester.tap(find.text('Restored shared words'));
    await settleEditor(tester);
    await tester.ensureVisible(find.text('Bluesky').last);
    await tester.tap(find.text('Bluesky').last);
    await settleEditor(tester);
    expect(find.byType(VersionScreen), findsOneWidget);
    await tester.tap(find.text('Own caption'));
    await tester.enterText(find.byType(TextField), 'Restored own words');
    await tester.tap(find.text('Done'));
    await settleEditor(tester);
    await tester.tap(find.text('Review post'));
    await settleEditor(tester);
    expect(find.byType(ReviewScreen), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CaptionText && w.text == 'Restored own words',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Publish to Bluesky'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Edit shared caption'));
    await tester.tap(find.text('Edit shared caption'));
    await settleEditor(tester);
    expect(find.byType(WriteScreen), findsOneWidget);
    expect(find.text('Done repairing'), findsNothing);
    expect(find.text('Restored shared words'), findsWidgets);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class DelayedAccounts extends ReviewAccounts {
  DelayedAccounts(this.gate);
  final Future<void> gate;
  @override
  Future<List<AccountView>> list() async {
    await gate;
    return super.list();
  }
}
