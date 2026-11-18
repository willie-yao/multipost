import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/design/caption_text.dart';
import 'package:cross_posting_app/design/caption_tokens.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/instagram/instagram_screen.dart';
import 'package:cross_posting_app/features/library/library_screen.dart';
import 'package:cross_posting_app/features/review/review_screen.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/instagram_fixture.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);

  testWidgets(
    'frozen own caption keeps cyan and source label in Library after draft deletion',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final package = (await tester.runAsync(() async {
        final reviewed = await s.reviewTwoPhotos('Matching words');
        final original = (await s.app.drafts.get(reviewed.draftId))!;
        final ownDraft = editOwnCaption(
          original,
          Destination.instagram,
          'Matching words',
          s.app.clock.now(),
        );
        await s.app.drafts.save(ownDraft, expectedRevision: original.revision);
        final ownReview = (await s.review.review(ownDraft)).snapshot;
        final package = await s.instagram.prepare(
          ownReview,
          operationId: 'own-color',
        );
        final changed = editOwnCaption(
          ownDraft,
          Destination.instagram,
          'Later mutable words',
          s.app.clock.now(),
        );
        await s.app.drafts.save(changed, expectedRevision: ownDraft.revision);
        await s.app.drafts.setDeleted(original.id, s.app.clock.now());
        await s.app.database.db.delete(
          'drafts',
          where: 'id = ?',
          whereArgs: [original.id],
        );
        return package;
      }))!;
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s.app)));
      await settleEditorUntil(
        tester,
        () => find.text('View prepared package').evaluate().isNotEmpty,
      );
      expect(
        tester.widget<Text>(find.text('Matching words')).textSpan?.style?.color,
        CaptionTokens.light.own,
      );
      expect(find.text('Own caption'), findsOneWidget);
      expect(find.text('Shared caption'), findsNothing);
      expect(find.text('Later mutable words'), findsNothing);
      expect(await tester.runAsync(s.app.drafts.list), isEmpty);
      await tester.tap(find.text('View prepared package'));
      await tester.pump();
      await settleEditorUntil(tester, _preparedPhotosReady);
      expect(find.text('Own caption'), findsOneWidget);
      expect(find.text('Later mutable words'), findsNothing);
      final caption = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'Matching words',
        ),
      );
      expect(caption.style!.color, CaptionTokens.light.own);
      expect(package.ownCaption, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'edits during final revalidation cannot delegate an outdated snapshot',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final snapshot = (await tester.runAsync(
        () => s.reviewTwoPhotos('Before await'),
      ))!;
      final draft = (await tester.runAsync(
        () => s.app.drafts.get(snapshot.draftId),
      ))!;
      final controller = DraftController(draft, s.app.drafts, s.app.clock);
      addTearDown(controller.dispose);
      final service = _PausedReview(s);
      var confirms = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: controller,
            service: service,
            onConfirm: (_) async {
              confirms++;
            },
          ),
        ),
      );
      await settleEditor(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Prepare Instagram'));
      await tester.pump();
      for (var i = 0; i < 100 && !service.started; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(service.started, isTrue);
      controller.change(
        editSharedCaption(
          controller.draft,
          'Changed during await',
          s.app.clock.now(),
        ),
      );
      service.release.complete();
      await settleEditorUntil(
        tester,
        () =>
            controller.saveState == SaveState.saved &&
            find
                .byWidgetPredicate(
                  (w) => w is CaptionText && w.text == 'Changed during await',
                )
                .evaluate()
                .isNotEmpty &&
            find.byType(LinearProgressIndicator).evaluate().isEmpty,
      );
      expect(confirms, 0);
      expect(await tester.runAsync(s.instagramRepo.pending), isEmpty);
    },
  );

  testWidgets(
    'real host prepares one local package and reopens it after draft deletion',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final snapshot = (await tester.runAsync(
        () => s.reviewTwoPhotos('Prepared words'),
      ))!;
      await tester.runAsync(() async {
        final draft = (await s.app.drafts.get(snapshot.draftId))!;
        await s.app.drafts.save(
          draft.copyWith(
            stage: ComposeStage.review,
            revision: draft.revision + 1,
          ),
          expectedRevision: draft.revision,
        );
      });
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s.app)));
      await settleEditor(tester);
      await tester.tap(find.text('Prepared words'));
      await settleEditor(tester);
      final prepare = find.widgetWithText(FilledButton, 'Prepare Instagram');
      expect(tester.widget<FilledButton>(prepare).onPressed, isNotNull);
      final queuedTap = tester.widget<FilledButton>(prepare).onPressed!;
      queuedTap();
      queuedTap();
      await settleEditorUntil(
        tester,
        () =>
            find.byType(InstagramScreen).evaluate().isNotEmpty &&
            _preparedPhotosReady(),
      );
      expect(find.text('Ready to share'), findsOneWidget);
      expect(find.text('Shared caption'), findsOneWidget);
      expect(
        tester
            .widget<SelectableText>(
              find.byWidgetPredicate(
                (w) => w is SelectableText && w.data == 'Prepared words',
              ),
            )
            .style!
            .color,
        CaptionTokens.light.text,
      );
      expect(find.byType(SelectableText), findsWidgets);
      expect((await tester.runAsync(s.instagramRepo.pending))!, hasLength(1));
      expect(find.text('Copy caption'), findsOneWidget);
      expect(find.text('Save photos'), findsOneWidget);
      expect((await tester.runAsync(s.app.attempts.listGroups))!, hasLength(1));
      await tester.tap(find.byTooltip('Back'));
      await settleEditor(tester);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.byType(ReviewScreen), findsNothing);
      expect(find.text('Prepared words'), findsNothing);
      await tester.tap(find.byTooltip('Back to library'));
      await settleEditor(tester);
      await tester.runAsync(
        () => s.app.drafts.setDeleted(snapshot.draftId, s.app.clock.now()),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s.app)));
      await settleEditor(tester);
      expect(find.text('Instagram needs finishing'), findsNothing);
      expect(find.text('Instagram · Ready to share'), findsOneWidget);
      expect(find.text('Review posting results'), findsOneWidget);
      await tester.tap(find.text('Review posting results'));
      await settleEditor(tester);
      await tester.tap(
        find.widgetWithText(FilledButton, 'Finish in Instagram'),
      );
      await tester.pump();
      await settleEditorUntil(tester, _preparedPhotosReady);
      expect(find.byType(InstagramScreen), findsOneWidget);
      expect(find.text('Prepared words'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Image &&
              (w.semanticLabel?.startsWith('Photo 1 of 2.') ?? false),
        ),
        findsOneWidget,
      );
      expect(find.text('Description 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'real host retains durable Instagram preparation failure in Results',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final snapshot = (await tester.runAsync(
        () => s.reviewTwoPhotos('Kept after failure'),
      ))!;
      await tester.runAsync(() async {
        final draft = (await s.app.drafts.get(snapshot.draftId))!;
        await s.app.drafts.save(
          draft.copyWith(
            stage: ComposeStage.review,
            revision: draft.revision + 1,
          ),
          expectedRevision: draft.revision,
        );
        await File(s.app.instagramPackageRoot.path)
            .writeAsString('fixture storage obstruction');
      });
      await tester.pumpWidget(CaptionApp(home: LibraryScreen(services: s.app)));
      await settleEditor(tester);
      await tester.tap(find.text('Kept after failure'));
      await settleEditor(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Prepare Instagram'));
      await settleEditorUntil(
        tester,
        () => find.byType(ResultsScreen).evaluate().isNotEmpty,
      );
      expect(find.byType(InstagramScreen), findsNothing);
      expect(find.text('Preparation needs attention'), findsOneWidget);
      final groups = (await tester.runAsync(s.app.attempts.listGroups))!;
      expect(groups, hasLength(1));
      final preparation = (await tester.runAsync(
        () => s.app.attempts.instagramPreparation(groups.single.id),
      ))!;
      expect(preparation.state, InstagramPreparationState.failed);
      expect(await tester.runAsync(s.instagramRepo.pending), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('stale final callbacks never prepare changed reviewed content', (
    tester,
  ) async {
    final s = (await tester.runAsync(instagramTestServices))!;
    addTearDown(s.close);
    final snapshot = (await tester.runAsync(
      () => s.reviewTwoPhotos('Before'),
    ))!;
    final draft = (await tester.runAsync(
      () => s.app.drafts.get(snapshot.draftId),
    ))!;
    final controller = DraftController(draft, s.app.drafts, s.app.clock);
    addTearDown(controller.dispose);
    var confirms = 0;
    await tester.pumpWidget(
      CaptionApp(
        home: ReviewScreen(
          controller: controller,
          service: s.review,
          onConfirm: (_) async {
            confirms++;
          },
        ),
      ),
    );
    await settleEditor(tester);
    final callback = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Prepare Instagram'),
        )
        .onPressed!;
    controller.change(
      editSharedCaption(
        controller.draft,
        'Changed before tap',
        s.app.clock.now(),
      ),
    );
    callback();
    await settleEditorUntil(
      tester,
      () =>
          controller.saveState == SaveState.saved &&
          find
              .byWidgetPredicate(
                (w) => w is CaptionText && w.text == 'Changed before tap',
              )
              .evaluate()
              .isNotEmpty &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty,
    );
    expect(confirms, 0);
    expect(await tester.runAsync(s.instagramRepo.pending), isEmpty);
    expect(find.text('This post changed. Review it again.'), findsOneWidget);
  });

  testWidgets(
    'preparation failure stays a local problem and serializes final action',
    (tester) async {
      final s = (await tester.runAsync(instagramTestServices))!;
      addTearDown(s.close);
      final snapshot = (await tester.runAsync(
        () => s.reviewTwoPhotos('Caption'),
      ))!;
      final draft = (await tester.runAsync(
        () => s.app.drafts.get(snapshot.draftId),
      ))!;
      final controller = DraftController(draft, s.app.drafts, s.app.clock);
      addTearDown(controller.dispose);
      final gate = Completer<void>();
      var confirms = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ReviewScreen(
            controller: controller,
            service: s.review,
            onConfirm: (_) async {
              confirms++;
              await gate.future;
              throw StateError('Storage unavailable');
            },
          ),
        ),
      );
      await settleEditor(tester);
      final callback = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Prepare Instagram'),
          )
          .onPressed!;
      callback();
      callback();
      for (var i = 0; i < 40 && confirms == 0; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pump();
      expect(confirms, 1);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Prepare Instagram'),
            )
            .onPressed,
        isNull,
      );
      gate.complete();
      await settleEditor(tester);
      expect(
        find.textContaining('This action could not finish'),
        findsOneWidget,
      );
      expect(find.text('Not published'), findsNothing);
      expect(await tester.runAsync(s.instagramRepo.pending), isEmpty);
    },
  );

  testWidgets('read-only prepared view reflows at 320 dp and 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final s = (await tester.runAsync(instagramTestServices))!;
    addTearDown(s.close);
    final package = (await tester.runAsync(
      () async => s.instagram.prepare(
        await s.reviewTwoPhotos(
          'A long reviewed caption that remains selectable and unchanged after preparing. ' *
              3,
        ),
        operationId: 'reflow',
      ),
    ))!;
    await tester.pumpWidget(
      CaptionApp(
        home: InstagramScreen(package: package, service: s.instagram),
      ),
    );
    await settleEditor(tester);
    await tester.ensureVisible(
      find.byWidgetPredicate(
        (w) =>
            w is Image &&
            (w.semanticLabel?.startsWith('Photo 2 of 2.') ?? false),
      ),
    );
    await settleEditor(tester);
    expect(find.text('Description 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _PausedReview extends ReviewService {
  _PausedReview(InstagramTestServices s)
    : super(
        s.app.drafts,
        s.app.media,
        s.app.accounts,
        s.validators,
        s.app.clock,
      );
  final release = Completer<void>();
  bool started = false;
  @override
  Future<ReviewResult> revalidate(
    ReviewedPost snapshot,
    Draft draft, {
    bool? directOnline,
  }) async {
    started = true;
    await release.future;
    return super.revalidate(snapshot, draft, directOnline: directOnline);
  }
}

// FileImage starts its own read after the integrity future resolves. Wait for
// decoded pixels, not just removal of the service's loading indicator.
bool _preparedPhotosReady() =>
    find
        .descendant(
          of: find.byType(InstagramScreen),
          matching: find.byWidgetPredicate(
            (widget) => widget is RawImage && widget.image != null,
          ),
        )
        .evaluate()
        .length ==
    2;
