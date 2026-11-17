import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/publishing/retry_edits.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/coordinator_fixture.dart';

void main() {
  testWidgets(
    'completed versions are disclosed and root rows do not duplicate history',
    (tester) async {
      final h = (await tester.runAsync(() => coordinatorHarness()))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      final attempts = (await tester.runAsync(
        () => h.attempts.effectiveAttempts(id),
      ))!;
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
          ),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Attempt history (2)'), findsNothing);
      expect(find.text('Refresh saved results'), findsNothing);
      expect(
        find.textContaining('Provider confirmed publication at'),
        findsNothing,
      );
      expect(find.textContaining('2026-11-'), findsNothing);
      expect(find.textContaining('Confirmed by X'), findsOneWidget);
      expect(
        find.byKey(ValueKey('reviewed-version-${attempts.first.id}')),
        findsOneWidget,
      );
      expect(find.text('Frozen caption'), findsOneWidget);
      await tester.ensureVisible(find.text('View reviewed version'));
      await tester.tap(find.text('View reviewed version'));
      await tester.pumpAndSettle();
      expect(find.text('Frozen caption'), findsNWidgets(2));
      expect(find.text('Hide reviewed version'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'processing Check stays read-only and only explicit Continue sends frozen content',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(
          selected: {Destination.x},
          x: [PublishStatus.processing, PublishStatus.published],
        ),
      ))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      h.x.onCheck = (_, _, _) async => PublishOutcome(
        status: PublishStatus.processing,
        source: EvidenceSource.provider,
        at: h.clock.now(),
        reasonCode: 'preparation-ready',
      );
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
          ),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(
        find.widgetWithText(OutlinedButton, 'Check X status'),
      );
      await tester.tap(find.widgetWithText(OutlinedButton, 'Check X status'));
      await settleEditor(tester);
      expect(h.x.sent, hasLength(1));
      final continuation = find.widgetWithText(
        OutlinedButton,
        'Continue publishing X',
      );
      await tester.ensureVisible(continuation);
      await tester.tap(continuation);
      await settleEditor(tester);
      expect(h.x.sent, hasLength(2));
      expect(h.x.sent.last.content.text, 'Frozen caption');
      expect(
        (await tester.runAsync(() => h.attempts.effectiveAttempts(id)))!
            .single
            .outcome
            .status,
        PublishStatus.published,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('direct failure makes its scoped review the dominant action', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => coordinatorHarness(selected: {Destination.bluesky}),
    ))!;
    addTearDown(h.close);
    final id = (await tester.runAsync(
      () => h.coordinator.confirm(h.review, operationId: 'original'),
    ))!;
    var reviews = 0;
    await tester.pumpWidget(
      CaptionApp(
        home: ResultsScreen(
          groupId: id,
          attempts: h.attempts,
          coordinator: h.coordinator,
          instagram: h.app.instagramRepo,
          onRetry: (_) async {
            reviews++;
          },
        ),
      ),
    );
    await settleEditor(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Review Bluesky retry'));
    await settleEditor(tester);
    expect(reviews, 1);
    expect(h.bluesky.sent, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'Send again opens only a new review and never sends from the result action',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(bluesky: [PublishStatus.unknown]),
      ))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      var reviews = 0;
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
            onRetry: (_) async {
              reviews++;
            },
          ),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Send again…'));
      await tester.tap(find.text('Send again…'));
      await settleEditor(tester);
      expect(reviews, 1);
      expect(h.bluesky.sent, hasLength(1));
      expect(
        (await tester.runAsync(() => h.attempts.effectiveAttempts(id)))!
            .last
            .outcome
            .status,
        PublishStatus.unknown,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Check opens the exact official profile and return retains Unknown without resending',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(bluesky: [PublishStatus.unknown]),
      ))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      final opened = <Uri>[];
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
            openExternal: (destination, uri) async {
              opened.add(uri);
              return true;
            },
          ),
        ),
      );
      await settleEditor(tester);
      await tester.ensureVisible(find.text('Check Bluesky'));
      await tester.tap(find.text('Check Bluesky'));
      await settleEditor(tester);
      expect(
        opened.single.toString(),
        'https://bsky.app/profile/did:plc:abcdefghijklmnopqrstuvwx',
      );
      expect(
        (await tester.runAsync(() => h.attempts.effectiveAttempts(id)))!
            .last
            .outcome
            .status,
        PublishStatus.unknown,
      );
      expect(h.bluesky.sent, hasLength(1));
      expect(find.text('I found the post'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('multiple provider receipts reveal both actual frozen captions', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => coordinatorHarness(
        bluesky: [PublishStatus.unknown, PublishStatus.published],
      ),
    ))!;
    addTearDown(h.close);
    final id = (await tester.runAsync(
      () => h.coordinator.confirm(h.review, operationId: 'original'),
    ))!;
    await tester.runAsync(() async {
      final parent = (await h.attempts.effectiveAttempts(id)).last;
      final draft = await RetryEdits(
        h.app.drafts,
        h.attempts,
        h.clock,
      ).open(parent.id);
      final edited = editOwnCaption(
        draft,
        Destination.bluesky,
        'Edited duplicate-risk caption',
        h.clock.now(),
      );
      await h.app.drafts.save(edited, expectedRevision: draft.revision);
      await h.coordinator.resendAfterCheck(
        parent.id,
        await h.reviewDraft(edited),
        operationId: draft.retryOperationId!,
        duplicateRiskAccepted: true,
      );
      h.bluesky.onCheck = (_, _, _) async =>
          h.bluesky.outcome(PublishStatus.published);
      await h.coordinator.check(parent.id);
    });
    await tester.pumpWidget(
      CaptionApp(
        home: ResultsScreen(
          groupId: id,
          attempts: h.attempts,
          coordinator: h.coordinator,
          instagram: h.app.instagramRepo,
        ),
      ),
    );
    await settleEditor(tester);
    expect(
      find.text(
        '2 provider-confirmed publications. More than one post may be visible.',
      ),
      findsOneWidget,
    );
    expect(find.text('View Bluesky receipt 1'), findsOneWidget);
    expect(find.text('View Bluesky receipt 2'), findsOneWidget);
    expect(find.text('Edited duplicate-risk caption'), findsNothing);
    final attempts = (await tester.runAsync(() => h.attempts.attempts(id)))!;
    for (final receipt in attempts.where(
      (a) => a.snapshot.destination == Destination.bluesky,
    )) {
      final disclosure = find.byKey(ValueKey('reviewed-version-${receipt.id}'));
      await tester.ensureVisible(disclosure);
      await tester.tap(disclosure);
      await tester.pumpAndSettle();
    }
    expect(find.text('Edited duplicate-risk caption'), findsOneWidget);
    expect(find.text('Frozen caption'), findsOneWidget);
    expect(find.text('Retry Bluesky'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('unknown offers check and explicit resend, never normal retry', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => coordinatorHarness(bluesky: [PublishStatus.unknown]),
    ))!;
    addTearDown(h.close);
    final id = (await tester.runAsync(
      () => h.coordinator.confirm(h.review, operationId: 'original'),
    ))!;
    await tester.pumpWidget(
      CaptionApp(
        home: ResultsScreen(
          groupId: id,
          attempts: h.attempts,
          coordinator: h.coordinator,
          instagram: h.app.instagramRepo,
        ),
      ),
    );
    await settleEditor(tester);
    expect(find.text('Check Bluesky'), findsOneWidget);
    expect(find.text('I found the post'), findsOneWidget);
    expect(find.text('Send again…'), findsOneWidget);
    expect(find.text('Retry Bluesky'), findsNothing);
    await tester.ensureVisible(find.text('I found the post'));
    await tester.tap(find.text('I found the post'));
    await settleEditor(tester);
    expect(
      find.text('You marked this as posted · not verified by the app'),
      findsOneWidget,
    );
    expect(h.bluesky.createCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'results use effective frozen content and reveal edited attempt history',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(
          bluesky: [PublishStatus.unknown, PublishStatus.notPublished],
        ),
      ))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      await tester.runAsync(() async {
        final parent = (await h.attempts.effectiveAttempts(id)).last;
        await h.coordinator.resendAfterCheck(
          parent.id,
          h.review,
          operationId: 'explicit-resend',
          duplicateRiskAccepted: true,
        );
        await h.coordinator.reportFound(parent.id);
      });
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
          ),
        ),
      );
      await settleEditor(tester);
      expect(find.text('Retry Bluesky'), findsNothing);
      expect(
        find.text('You marked this as posted · not verified by the app'),
        findsOneWidget,
      );
      final history = find.text('Attempt history (3)');
      await tester.ensureVisible(history);
      await tester.tap(history);
      await tester.pumpAndSettle();
      expect(find.textContaining('Not published'), findsWidgets);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('results reflow at 320dp and 200 percent without sending', (
    tester,
  ) async {
    final h = (await tester.runAsync(
      () => coordinatorHarness(bluesky: [PublishStatus.unknown]),
    ))!;
    addTearDown(h.close);
    final id = (await tester.runAsync(
      () => h.coordinator.confirm(h.review, operationId: 'original'),
    ))!;
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      CaptionApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: ResultsScreen(
            groupId: id,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
          ),
        ),
      ),
    );
    await settleEditor(tester);
    expect(tester.takeException(), isNull);
    expect(h.x.sent, hasLength(1));
    expect(h.bluesky.sent, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
