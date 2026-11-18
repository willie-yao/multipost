import 'dart:io';

import 'package:cross_posting_app/app/app.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/publishing/retry_edits.dart';
import 'package:cross_posting_app/features/publishing/results_screen.dart';
import 'package:cross_posting_app/features/media/media_strip.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/app_fixture.dart';
import '../../support/coordinator_fixture.dart';
import '../../support/review_fixtures.dart';

void main() {
  for (final earlierVideo in [false, true]) {
    for (final imageDestination in [
      Destination.bluesky,
      Destination.instagram,
    ]) {
      testWidgets(
        'Results header finds the first image in $imageDestination after ${earlierVideo ? 'video' : 'text-only'} X',
        (tester) async {
          final h = (await tester.runAsync(() => coordinatorHarness()))!;
          addTearDown(h.close);
          final original = (await tester.runAsync(
            () => h.app.drafts.get(h.review.draftId),
          ))!;
          final video = earlierVideo
              ? (await tester.runAsync(
                  () => syntheticVideo(
                    h.app.media.root,
                    h.app.database.db.insert,
                  ),
                ))!
              : null;
          final draft = original.copyWith(
            revision: 1,
            versions: {
              Destination.x: DestinationVersion(
                ownMedia: [if (video != null) Attachment(assetId: video.id)],
              ),
              if (imageDestination == Destination.instagram)
                Destination.bluesky: DestinationVersion(ownMedia: []),
            },
          );
          final id = (await tester.runAsync(() async {
            await h.app.drafts.save(draft, expectedRevision: 0);
            final reviewed = await h.reviewDraft(draft);
            return h.coordinator.confirm(reviewed, operationId: 'later-image');
          }))!;
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
          final header = find.descendant(
            of: find.byKey(const ValueKey('results-header-photo')),
            matching: find.byType(MediaPreview),
          );
          expect(header, findsOneWidget);
          expect(
            tester.widget<MediaPreview>(header).attachment.assetId,
            draft.shared.media.single.assetId,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }
  testWidgets(
    'Results header uses distinct effective retry photo instead of original photo',
    (tester) async {
      final h = (await tester.runAsync(
        () =>
            coordinatorHarness(selected: {Destination.x, Destination.bluesky}),
      ))!;
      addTearDown(h.close);
      final result = (await tester.runAsync(() async {
        final original = (await h.app.drafts.get(h.review.draftId))!;
        final source = original.copyWith(
          revision: 1,
          versions: {Destination.x: DestinationVersion(ownMedia: [])},
        );
        await h.app.drafts.save(source, expectedRevision: original.revision);
        final groupId = await h.coordinator.confirm(
          await h.reviewDraft(source),
          operationId: 'original-photo',
        );
        final parent = (await h.attempts.effectiveAttempts(groupId)).last;
        final draft = await RetryEdits(
          h.app.drafts,
          h.attempts,
          h.clock,
        ).open(parent.id);
        final imageFile = File(
          '${h.app.media.root.parent.path}/distinct-retry.png',
        );
        final image = img.Image(width: 11, height: 7);
        img.fill(image, color: img.ColorRgb8(210, 40, 70));
        await imageFile.writeAsBytes(img.encodePng(image));
        final asset = await h.app.media.importFile(XFile(imageFile.path));
        final edited = editOwnMedia(draft, Destination.bluesky, [
          Attachment(assetId: asset.id, altText: 'Distinct retry image'),
        ], h.clock.now());
        await h.app.drafts.save(edited, expectedRevision: draft.revision);
        await h.coordinator.retry(
          parent.id,
          await h.reviewDraft(edited),
          operationId: draft.retryOperationId!,
        );
        expect(asset.id, isNot(source.shared.media.single.assetId));
        expect(asset.sha256, isNot(parent.snapshot.assets.single.sha256));
        expect(
          (await h.attempts.getGroup(groupId))!
              .snapshot
              .posts[Destination.bluesky]!
              .assets
              .single
              .id,
          source.shared.media.single.assetId,
        );
        return (groupId, asset.id);
      }))!;
      await tester.pumpWidget(
        CaptionApp(
          home: ResultsScreen(
            groupId: result.$1,
            attempts: h.attempts,
            coordinator: h.coordinator,
            instagram: h.app.instagramRepo,
          ),
        ),
      );
      await settleEditor(tester);
      final header = find.descendant(
        of: find.byKey(const ValueKey('results-header-photo')),
        matching: find.byType(MediaPreview),
      );
      expect(header, findsOneWidget);
      expect(tester.widget<MediaPreview>(header).attachment.assetId, result.$2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'Instagram Results retains handoff through mark and Undo without claiming publication',
    (tester) async {
      final h = (await tester.runAsync(
        () => coordinatorHarness(selected: {Destination.instagram}),
      ))!;
      addTearDown(h.close);
      final id = (await tester.runAsync(
        () => h.coordinator.confirm(h.review, operationId: 'original'),
      ))!;
      final preparation = (await tester.runAsync(
        () => h.attempts.instagramPreparation(id),
      ))!;
      final packageId = preparation.packageId!;
      await tester.runAsync(
        () => h.app.instagramRepo.append(
          packageId,
          InstagramEvent(
            id: 'dispatch',
            kind: InstagramEventKind.targetDispatched,
            at: h.clock.now(),
            launchId: 'retained-trip',
            targetPackage: 'com.instagram.android',
          ),
        ),
      );
      Future<void> reopen(String state) async {
        await tester.pumpWidget(
          CaptionApp(
            home: ResultsScreen(
              key: ValueKey(state),
              groupId: id,
              attempts: h.attempts,
              coordinator: h.coordinator,
              instagram: h.app.instagramRepo,
            ),
          ),
        );
        await settleEditor(tester);
      }

      await reopen('handed-off');
      expect(find.text('Instagram · Handed off'), findsOneWidget);
      expect(find.text('Handed off'), findsOneWidget);
      expect(
        find.text('Photos handed to Instagram. Posting is not confirmed.'),
        findsOneWidget,
      );
      expect(find.text('Ready to share'), findsNothing);
      await tester.runAsync(() => h.instagram.markPosted(packageId));
      await reopen('marked');
      expect(find.text('Instagram · Marked posted'), findsOneWidget);
      expect(
        find.text('Your confirmation on this phone · not verified by the app'),
        findsOneWidget,
      );
      await tester.runAsync(() => h.instagram.undoMarked(packageId));
      await reopen('undone');
      expect(find.text('Instagram · Handed off'), findsOneWidget);
      expect(find.text('Handed off'), findsOneWidget);
      expect(
        find.text('Photos handed to Instagram. Posting is not confirmed.'),
        findsOneWidget,
      );
      expect(find.text('Ready to share'), findsNothing);
      expect(find.text('Published'), findsNothing);
      expect(
        (await tester.runAsync(() => h.app.instagramRepo.progress(packageId)))!
            .state,
        InstagramState.handedOff,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
    await tester.pumpAndSettle();
    // Marking is the person's own word, so it is confirmed first.
    expect(find.text('Mark Bluesky as posted?'), findsOneWidget);
    await tester.tap(find.text('Mark as posted'));
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
