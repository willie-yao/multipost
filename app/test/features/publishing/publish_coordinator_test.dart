import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/publishing/attempt_repository.dart';
import 'package:cross_posting_app/features/publishing/publish_coordinator.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coordinator_fixture.dart';

void main() {
  test('retrying failed Bluesky never repeats published X or Instagram preparation', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'review-1',
    );
    expect(
      await h.coordinator.confirm(h.review, operationId: 'review-1'),
      group,
    );
    final failed = (await h.attempts.attempts(group))
        .singleWhere((a) => a.snapshot.destination == Destination.bluesky);
    final child = await h.coordinator.retry(
      failed.id,
      h.review,
      operationId: 'retry-1',
    );
    expect(h.x.sent.length, 1);
    expect(h.bluesky.sent.length, 2);
    expect(h.instagram.prepareCount, 1);
    expect((await h.attempts.getAttempt(child))!.parentId, failed.id);
    expect((await h.attempts.getGroup(group))!.snapshot.posts.length, 3);
  });

  test(
    'simultaneous coordinators deduplicate confirm with a durable group claim',
    () async {
      final h = await coordinatorHarness(bluesky: [PublishStatus.published]);
      addTearDown(h.close);
      final other = h.makeCoordinator(
        repository: AttemptRepository(h.app.database, h.clock, h.app.ids),
      );
      final groups = await Future.wait([
        h.coordinator.confirm(h.review, operationId: 'tap'),
        other.confirm(h.review, operationId: 'tap'),
      ]);
      expect(groups.toSet().length, 1);
      expect(h.x.createCount, 1);
      expect(h.bluesky.createCount, 1);
      expect(h.instagram.prepareCount, 1);
      expect(
        (await h.attempts.attempts(groups.first))
            .every((a) => a.outcome.status == PublishStatus.published),
        isTrue,
      );
    },
  );

  test(
    'restart leaves later pending rows unsent until explicitly selected',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      final begun = await h.attempts.begin(h.review, 'begun');
      await h.attempts.recoverInterrupted();
      final pending = await h.attempts.attempts(begun.group.id);
      expect(h.x.sent, isEmpty);
      expect(h.bluesky.sent, isEmpty);
      expect(
        await h.coordinator.confirm(h.review, operationId: 'new-tap'),
        begun.group.id,
      );
      expect(h.x.sent, isEmpty);
      await h.coordinator.continuePending(
        begun.group.id,
        h.review,
        attemptIds: {pending.first.id},
      );
      expect(h.x.sent.length, 1);
      expect(h.bluesky.sent, isEmpty);
      expect(
        (await h.attempts.getAttempt(pending.last.id))!.outcome.status,
        PublishStatus.pending,
      );
      expect(h.instagram.prepareCount, 0);
    },
  );

  test('processing Check is read only and explicit continuation gets freshly persisted uploads', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    h.x.onSend = (post, context) async {
      if (h.x.sent.length == 1) {
        await context.saveUpload('opaque-upload', 'processing');
        return h.x.outcome(PublishStatus.processing);
      }
      expect(context.uploadState, {'opaque-upload': 'ready'});
      await context.markDispatch();
      h.x.createCount++;
      return h.x.outcome(PublishStatus.published);
    };
    h.x.onCheck = (post, previous, context) async {
      expect(context.uploadState, {'opaque-upload': 'processing'});
      await context.saveUpload('opaque-upload', 'ready');
      await expectLater(context.markDispatch(), throwsStateError);
      return PublishOutcome(
        status: PublishStatus.processing,
        source: EvidenceSource.local,
        at: h.clock.now(),
        reasonCode: 'preparation-ready',
      );
    };
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    await expectLater(
      h.coordinator.retry(attempt.id, h.review, operationId: 'ordinary'),
      throwsStateError,
    );
    await h.coordinator.check(attempt.id);
    expect(h.x.sent.length, 1);
    expect(h.x.createCount, 0);
    expect(h.x.contexts.first.uploadState, isEmpty);
    await h.coordinator.continuePending(
      group,
      h.review,
      attemptIds: {attempt.id},
    );
    expect(h.x.sent.length, 2);
    expect(h.x.createCount, 1);
    expect(
      (await h.attempts.getAttempt(attempt.id))!.outcome.status,
      PublishStatus.published,
    );
  });

  test('lost final response is unknown, ordinary retry blocked, user found carries no invented receipt', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    await expectLater(
      h.coordinator.retry(attempt.id, h.review, operationId: 'unsafe'),
      throwsStateError,
    );
    await expectLater(
      h.coordinator.resendAfterCheck(
        attempt.id,
        h.review,
        operationId: 'risk',
        duplicateRiskAccepted: false,
      ),
      throwsStateError,
    );
    expect(h.x.checkCount, 0);
    await h.coordinator.reportFound(attempt.id);
    final found = (await h.attempts.getAttempt(attempt.id))!;
    expect(found.outcome.status, PublishStatus.userReported);
    expect(found.outcome.source, EvidenceSource.user);
    expect(found.outcome.remoteId, isNull);
    expect(found.outcome.url, isNull);
    await expectLater(h.coordinator.reportFound(attempt.id), throwsStateError);
    await expectLater(
      h.coordinator.retry(attempt.id, h.review, operationId: 'again'),
      throwsStateError,
    );
    expect(h.x.createCount, 1);
  });

  test('duplicate-risk resend checks first and starts child with empty state and no dispatch marker', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown, PublishStatus.published],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    h.x.onSend = (post, context) async {
      if (h.x.sent.length == 1) {
        await context.saveUpload('provider-dispatch-evidence', 'old');
        await context.markDispatch();
        h.x.createCount++;
        return h.x.outcome(PublishStatus.unknown);
      }
      expect(context.uploadState, isEmpty);
      expect(
        (await h.attempts.getAttempt(context.attemptId))!.dispatchAt,
        isNull,
      );
      await context.markDispatch();
      h.x.createCount++;
      return h.x.outcome(PublishStatus.published);
    };
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final parent = (await h.attempts.attempts(group)).single;
    final child = await h.coordinator.resendAfterCheck(
      parent.id,
      h.review,
      operationId: 'risk',
      duplicateRiskAccepted: true,
    );
    expect(
      await h.coordinator.resendAfterCheck(
        parent.id,
        h.review,
        operationId: 'risk',
        duplicateRiskAccepted: true,
      ),
      child,
    );
    expect(h.x.checkCount, 1);
    expect(h.x.createCount, 2);
    expect(
      (await h.attempts.getAttempt(parent.id))!.outcome.status,
      PublishStatus.unknown,
    );
    await expectLater(
      h.coordinator.resendAfterCheck(
        parent.id,
        h.review,
        operationId: 'another',
        duplicateRiskAccepted: true,
      ),
      throwsStateError,
    );
    await expectLater(h.coordinator.reportFound(parent.id), throwsStateError);
    expect(h.x.createCount, 2);
  });

  test(
    'successful official check closes unknown without duplicate create',
    () async {
      final h = await coordinatorHarness(
        x: [PublishStatus.unknown],
        selected: {Destination.x},
      );
      addTearDown(h.close);
      h.x.onCheck = (post, previous, context) async =>
          h.x.outcome(PublishStatus.published);
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      final parent = (await h.attempts.attempts(group)).single;
      await expectLater(
        h.coordinator.resendAfterCheck(
          parent.id,
          h.review,
          operationId: 'risk',
          duplicateRiskAccepted: true,
        ),
        throwsStateError,
      );
      expect(
        (await h.attempts.getAttempt(parent.id))!.outcome.status,
        PublishStatus.published,
      );
      expect(h.x.createCount, 1);
      expect((await h.attempts.attempts(group)).length, 1);
    },
  );

  test('failed-only retry accepts re-reviewed own caption and ignores an expired successful destination', () async {
    final h = await coordinatorHarness(
      bluesky: [PublishStatus.notPublished, PublishStatus.published],
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final parent = (await h.attempts.attempts(group)).last;
    final draft = (await h.app.drafts.get(h.review.draftId))!;
    final changed = editOwnCaption(
      draft,
      Destination.bluesky,
      'Edited own caption',
      h.clock.now(),
    );
    await h.app.drafts.save(changed, expectedRevision: draft.revision);
    final reviewed = await h.reviewDraft(changed);
    final xAccount = await h.app.accounts.get(Destination.x);
    await h.app.accounts.save(xAccount.copyWith(state: AccountState.expired));
    final childId = await h.coordinator.retry(
      parent.id,
      reviewed,
      operationId: 'retry',
    );
    final child = (await h.attempts.getAttempt(childId))!;
    expect(child.snapshot.content.text, 'Edited own caption');
    expect(child.snapshot.ownCaption, isTrue);
    expect(
      (await h.attempts.reviewForAttempt(childId)).revision,
      changed.revision,
    );
    expect(
      (await h.attempts.getGroup(group))!
          .snapshot
          .posts[Destination.bluesky]!
          .content
          .text,
      'Frozen caption',
    );
    expect(h.x.sent.length, 1);
    expect(h.instagram.prepareCount, 1);
    await expectLater(
      h.coordinator.retry(parent.id, reviewed, operationId: 'stale-parent'),
      throwsStateError,
    );
    expect(h.bluesky.sent.length, 2);
  });

  test(
    'only latest failed leaf can retry, operation taps reuse the same child',
    () async {
      final h = await coordinatorHarness(
        x: [
          PublishStatus.notPublished,
          PublishStatus.notPublished,
          PublishStatus.published,
        ],
        selected: {Destination.x},
      );
      addTearDown(h.close);
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      final root = (await h.attempts.attempts(group)).single;
      final children = await Future.wait([
        h.coordinator.retry(root.id, h.review, operationId: 'retry'),
        h.coordinator.retry(root.id, h.review, operationId: 'retry'),
      ]);
      expect(children.toSet().length, 1);
      expect(h.x.sent.length, 2);
      await expectLater(
        h.coordinator.retry(root.id, h.review, operationId: 'old-root'),
        throwsStateError,
      );
      final leaf = await h.coordinator.retry(
        children.first,
        h.review,
        operationId: 'next',
      );
      expect((await h.attempts.getAttempt(leaf))!.parentId, children.first);
      expect(h.x.sent.length, 3);
    },
  );

  test('stale saved review and changed account are rejected before creating a group', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final account = await h.app.accounts.get(Destination.x);
    await h.app.accounts.save(
      account.copyWith(
        identity: account.identity!.copyWith(subject: 'another-account'),
      ),
    );
    await expectLater(
      h.coordinator.confirm(h.review, operationId: 'wrong-account'),
      throwsA(isA<StaleReviewException>()),
    );
    expect(await h.app.database.db.query('attempt_groups'), isEmpty);
    await h.app.accounts.save(account);
    final draft = (await h.app.drafts.get(h.review.draftId))!;
    await h.app.drafts.save(
      editSharedCaption(draft, 'Newer text', h.clock.now()),
      expectedRevision: draft.revision,
    );
    await expectLater(
      h.coordinator.confirm(h.review, operationId: 'stale'),
      throwsA(isA<StaleReviewException>()),
    );
    expect(h.x.sent, isEmpty);
    expect(h.instagram.prepareCount, 0);
  });

  test('frozen continuation rejects a newer supplied review and publishes exact retained content', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'begun');
    final pending = (await h.attempts.attempts(group.group.id)).single;
    final draft = (await h.app.drafts.get(h.review.draftId))!;
    final changed = editSharedCaption(
      draft,
      'Newer editable caption',
      h.clock.now(),
    );
    await h.app.drafts.save(changed, expectedRevision: draft.revision);
    final newer = await h.reviewDraft(changed);
    await expectLater(
      h.coordinator.continuePending(
        group.group.id,
        newer,
        attemptIds: {pending.id},
      ),
      throwsA(isA<StaleReviewException>()),
    );
    expect(h.x.sent, isEmpty);
    await h.coordinator.continuePending(
      group.group.id,
      h.review,
      attemptIds: {pending.id},
    );
    expect(h.x.sent.single.content.text, 'Frozen caption');
    expect(
      (await h.app.drafts.get(h.review.draftId))!.shared.text,
      'Newer editable caption',
    );
  });

  test('explicit continuation rechecks account capability owned media and current network availability', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'begun');
    final pending = (await h.attempts.attempts(group.group.id)).single;
    Future<void> continueIt() => h.coordinator.continuePending(
      group.group.id,
      h.review,
      attemptIds: {pending.id},
    );
    h.online = null;
    await expectLater(continueIt(), throwsA(isA<PublishReviewRejected>()));
    h.online = false;
    await expectLater(continueIt(), throwsA(isA<PublishReviewRejected>()));
    h.online = true;
    h.directValidator.versionValue = 'new-version';
    await expectLater(continueIt(), throwsA(isA<StaleReviewException>()));
    h.directValidator.versionValue = 'verified-1';
    final account = await h.app.accounts.get(Destination.x);
    await h.app.accounts.save(
      account.copyWith(
        identity: account.identity!.copyWith(subject: 'switched'),
      ),
    );
    await expectLater(continueIt(), throwsA(isA<StaleReviewException>()));
    await h.app.accounts.save(account);
    final file = await h.app.media.fileFor(pending.snapshot.assets.single.id);
    await file.writeAsBytes([1, 2, 3], flush: true);
    await expectLater(continueIt(), throwsA(isA<StaleReviewException>()));
    expect(h.x.sent, isEmpty);
    expect(
      (await h.attempts.getAttempt(pending.id))!.outcome.status,
      PublishStatus.pending,
    );
  });

  test('provider retry date blocks early children and reconnect needs fresh review', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    h.x.onSend = (post, context) async => PublishOutcome(
      status: PublishStatus.connectionNeeded,
      source: EvidenceSource.local,
      at: h.clock.now(),
      retryAfter: h.clock.now().add(const Duration(minutes: 5)),
    );
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final parent = (await h.attempts.attempts(group)).single;
    await expectLater(
      h.coordinator.retry(parent.id, h.review, operationId: 'early'),
      throwsStateError,
    );
    h.clock.value = h.clock.value.add(const Duration(minutes: 5));
    final account = await h.app.accounts.get(Destination.x);
    await h.app.accounts.save(account.copyWith(state: AccountState.expired));
    await expectLater(
      h.coordinator.retry(parent.id, h.review, operationId: 'expired'),
      throwsA(isA<PublishReviewRejected>()),
    );
    await h.app.accounts.save(account);
    await h.coordinator.retry(parent.id, h.review, operationId: 'ready');
    expect(h.x.sent.length, 2);
  });

  test('dispatch storage failure prevents create without erasing another destination result', () async {
    final h = await coordinatorHarness(bluesky: [PublishStatus.published]);
    addTearDown(h.close);
    await h.app.database.db.execute(
      "CREATE TRIGGER reject_x_dispatch BEFORE UPDATE ON destination_attempts WHEN NEW.state = 'sending' AND NEW.destination = 'x' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final rows = await h.attempts.attempts(group);
    expect(h.x.createCount, 0);
    expect(rows.first.outcome.status, PublishStatus.notPublished);
    expect(rows.first.dispatchAt, isNull);
    expect(rows.last.outcome.status, PublishStatus.published);
    expect(h.bluesky.createCount, 1);
  });

  test('success lost before outcome commit stays unknown until exact provider reconciliation', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    await h.app.database.db.execute(
      "CREATE TRIGGER reject_success BEFORE UPDATE ON destination_attempts WHEN NEW.state = 'published' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
    );
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    expect(attempt.outcome.status, PublishStatus.unknown);
    expect(h.x.createCount, 1);
    expect(attempt.outcome.remoteId, '1234567890');
    expect(attempt.outcome.source, EvidenceSource.local);
    expect(attempt.outcome.url, isNull);
    await h.app.database.db.execute('DROP TRIGGER reject_success');
    h.x.onCheck = (post, previous, context) async =>
        h.x.outcome(PublishStatus.published);
    await h.coordinator.check(attempt.id);
    expect(
      (await h.attempts.getAttempt(attempt.id))!.outcome.status,
      PublishStatus.published,
    );
    expect(h.x.createCount, 1);
  });

  test('unexpected preparation exception stays safe and later direct destination still publishes', () async {
    final h = await coordinatorHarness(bluesky: [PublishStatus.published]);
    addTearDown(h.close);
    h.x.onSend = (post, context) async =>
        throw const FileSystemException('Synthetic pre-create failure');
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final rows = await h.attempts.attempts(group);
    expect(rows.first.outcome.status, PublishStatus.notPublished);
    expect(rows.last.outcome.status, PublishStatus.published);
    expect(h.instagram.prepareCount, 1);
  });

  test('Instagram-only failure has durable explicit continuation and no publication attempt', () async {
    final h = await coordinatorHarness(selected: {Destination.instagram});
    addTearDown(h.close);
    h.instagram.fail = true;
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    expect(await h.attempts.attempts(group), isEmpty);
    expect(
      (await h.attempts.instagramPreparation(group))!.state,
      InstagramPreparationState.failed,
    );
    expect(await h.coordinator.confirm(h.review, operationId: 'repeat'), group);
    expect(h.instagram.prepareCount, 1);
    h.instagram.fail = false;
    final draft = (await h.app.drafts.get(h.review.draftId))!;
    await h.app.drafts.save(
      editSharedCaption(draft, 'Edited later', h.clock.now()),
      expectedRevision: draft.revision,
    );
    await h.coordinator.continueInstagram(group, h.review);
    final preparation = (await h.attempts.instagramPreparation(group))!;
    expect(preparation.state, InstagramPreparationState.ready);
    expect(
      (await h.app.instagramRepo.get(preparation.packageId!))!.caption,
      'Frozen caption',
    );
    expect(h.x.sent, isEmpty);
    expect(h.bluesky.sent, isEmpty);
  });

  test('Instagram failure cannot prevent independent direct results', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    h.instagram.fail = true;
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    expect(
      (await h.attempts.instagramPreparation(group))!.state,
      InstagramPreparationState.failed,
    );
    expect(h.x.createCount, 1);
    expect(h.bluesky.sent.length, 1);
  });

  test('restart finds package committed before group association without preparing a duplicate', () async {
    final h = await coordinatorHarness(selected: {Destination.instagram});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'begun');
    await h.attempts.claimInstagram(group.group.id);
    final preparation = (await h.attempts.instagramPreparation(
      group.group.id,
    ))!;
    final package = await h.instagram.prepare(
      h.review,
      operationId: preparation.operationId,
    );
    await h.attempts.recoverInterrupted();
    expect(h.instagram.prepareCount, 1);
    expect(
      (await h.attempts.instagramPreparation(group.group.id))!.state,
      InstagramPreparationState.pending,
    );
    await h.coordinator.continueInstagram(group.group.id, h.review);
    expect(
      (await h.attempts.instagramPreparation(group.group.id))!.packageId,
      package.id,
    );
    expect((await h.app.database.db.query('instagram_packages')).length, 1);
    await h.coordinator.continueInstagram(group.group.id, h.review);
    expect(h.instagram.prepareCount, 2);
  });

  test('AppServices exposes durable publishing without granting unavailable production gates', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    expect(h.app.publishing.providers, isEmpty);
    await expectLater(
      h.app.publishing.confirm(h.review, operationId: 'production-unavailable'),
      throwsA(anything),
    );
    expect(await h.app.database.db.query('attempt_groups'), isEmpty);
    final group = await h.app.attempts.begin(h.review, 'journal-only');
    expect((await h.app.attempts.getGroup(group.group.id))!.snapshot, h.review);
    expect(h.x.sent, isEmpty);
  });

  test(
    'pending edited child continues its own frozen revision and capability',
    () async {
      final h = await coordinatorHarness(
        x: [PublishStatus.notPublished],
        selected: {Destination.x},
      );
      addTearDown(h.close);
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      final root = (await h.attempts.attempts(group)).single;
      final draft = (await h.app.drafts.get(h.review.draftId))!;
      final edited = editOwnCaption(
        draft,
        Destination.x,
        'Child own caption',
        h.clock.now(),
      );
      await h.app.drafts.save(edited, expectedRevision: draft.revision);
      h.directValidator.versionValue = 'updated-capability';
      final reviewed = await h.reviewDraft(edited);
      final child = (await h.attempts.createChild(
        root.id,
        reviewed,
        'recorded-before-crash',
      )).attempt;
      final frozen = await h.attempts.reviewForAttempt(child.id);
      await h.app.drafts.save(
        editSharedCaption(edited, 'Even newer shared caption', h.clock.now()),
        expectedRevision: edited.revision,
      );
      await h.attempts.recoverInterrupted();
      h.x.onSend = (post, context) async {
        await context.markDispatch();
        h.x.createCount++;
        return h.x.outcome(PublishStatus.published);
      };
      await h.coordinator.continuePending(
        group,
        frozen,
        attemptIds: {child.id},
      );
      expect(h.x.sent.last.content.text, 'Child own caption');
      expect(h.x.sent.last.ownCaption, isTrue);
      expect(
        (await h.attempts.getGroup(group))!
            .snapshot
            .capabilityVersions[Destination.x],
        'verified-1',
      );
      expect(frozen.capabilityVersions[Destination.x], 'updated-capability');
    },
  );

  test(
    'Instagram status write failure does not stop independent direct sends',
    () async {
      final h = await coordinatorHarness(bluesky: [PublishStatus.published]);
      addTearDown(h.close);
      h.instagram.fail = true;
      await h.app.database.db.execute(
        "CREATE TRIGGER reject_ig_failure BEFORE UPDATE ON attempt_groups WHEN NEW.instagram_state = 'failed' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      expect(h.x.createCount, 1);
      expect(h.bluesky.createCount, 1);
      expect(
        (await h.attempts.instagramPreparation(group))!.state,
        InstagramPreparationState.preparing,
      );
      await h.app.database.db.execute('DROP TRIGGER reject_ig_failure');
      await h.attempts.recoverInterrupted();
      expect(
        (await h.attempts.instagramPreparation(group))!.state,
        InstagramPreparationState.pending,
      );
    },
  );

  test('concurrent explicit preparation continuations claim once and retain the same package', () async {
    final h = await coordinatorHarness(selected: {Destination.instagram});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'begun');
    await Future.wait([
      h.coordinator.continueInstagram(group.group.id, h.review),
      h.makeCoordinator().continueInstagram(group.group.id, h.review),
    ]);
    expect(h.instagram.prepareCount, 1);
    expect((await h.app.database.db.query('instagram_packages')).length, 1);
  });

  test('concurrent Check excludes continuation while preserving current preparation evidence', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    h.x.onSend = (post, context) async => PublishOutcome(
      status: PublishStatus.processing,
      source: EvidenceSource.local,
      at: h.clock.now(),
      reasonCode: 'preparation-ready',
    );
    final entered = Completer<void>();
    final finish = Completer<void>();
    h.x.onCheck = (post, previous, context) async {
      entered.complete();
      await finish.future;
      return previous;
    };
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    final checking = h.coordinator.check(attempt.id);
    await entered.future;
    await h.coordinator.continuePending(
      group,
      h.review,
      attemptIds: {attempt.id},
    );
    expect(h.x.sent.length, 1);
    finish.complete();
    await checking;
    expect(
      (await h.attempts.getAttempt(attempt.id))!.outcome.status,
      PublishStatus.processing,
    );
  });

  test('an active continuation excludes Check and completed publication rejects stale callbacks', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    h.x.onSend = (post, context) async => PublishOutcome(
      status: PublishStatus.processing,
      source: EvidenceSource.local,
      at: h.clock.now(),
      reasonCode: 'preparation-ready',
    );
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    late PublishContext checkedContext;
    h.x.onCheck = (post, previous, context) async {
      checkedContext = context;
      await context.saveUpload('opaque-ready', 'newer');
      return previous;
    };
    await h.coordinator.check(attempt.id);
    final entered = Completer<void>();
    final finish = Completer<void>();
    h.x.onSend = (post, context) async {
      entered.complete();
      await finish.future;
      await context.markDispatch();
      h.x.createCount++;
      return h.x.outcome(PublishStatus.published);
    };
    final continuing = h.coordinator.continuePending(
      group,
      h.review,
      attemptIds: {attempt.id},
    );
    await entered.future;
    await h.coordinator.check(attempt.id);
    expect(h.x.checkCount, 1);
    finish.complete();
    await continuing;
    await expectLater(
      checkedContext.saveUpload('opaque-ready', 'stale'),
      throwsStateError,
    );
    await expectLater(
      h.attempts.record(
        attempt.id,
        PublishOutcome(
          status: PublishStatus.processing,
          source: EvidenceSource.local,
          at: h.clock.now(),
        ),
      ),
      throwsStateError,
    );
    final published = (await h.attempts.getAttempt(attempt.id))!;
    expect(published.outcome.status, PublishStatus.published);
    expect(published.uploadState, {'opaque-ready': 'newer'});
    expect(h.x.createCount, 1);
  });

  test('submitted draft stage-only revision opens existing result without another send', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final original = (await h.app.drafts.get(h.review.draftId))!;
    final moved = setStage(original, ComposeStage.review, h.clock.now());
    await h.app.drafts.save(moved, expectedRevision: original.revision);
    final newer = await h.reviewDraft(moved);
    expect(
      await h.coordinator.confirm(newer, operationId: 'stage-revision'),
      group,
    );
    expect(h.x.createCount, 1);
    expect(h.bluesky.sent.length, 1);
    expect(h.instagram.prepareCount, 1);
    expect((await h.app.database.db.query('attempt_groups')).length, 1);
    expect((await h.attempts.getGroupForDraft(original.id))!.id, group);
  });

  test('submitted draft edited caption and capabilities keep existing result and local edits', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final original = (await h.app.drafts.get(h.review.draftId))!;
    final edited = editSharedCaption(
      original,
      'Preserved local edit',
      h.clock.now(),
    );
    await h.app.drafts.save(edited, expectedRevision: original.revision);
    h.directValidator.versionValue = 'updated-capability';
    final newer = await h.reviewDraft(edited);
    expect(
      await h.coordinator.confirm(newer, operationId: 'different-content'),
      group,
    );
    expect(await h.coordinator.confirm(newer, operationId: 'first'), group);
    expect(
      (await h.app.drafts.get(edited.id))!.shared.text,
      'Preserved local edit',
    );
    expect(
      (await h.attempts.getGroup(group))!
          .snapshot
          .posts[Destination.x]!
          .content
          .text,
      'Frozen caption',
    );
    expect(h.x.createCount, 1);
    expect(h.bluesky.sent.length, 1);
    expect(h.instagram.prepareCount, 1);
  });

  test(
    'a deliberate new draft identity may submit the same exact content again',
    () async {
      final h = await coordinatorHarness(selected: {Destination.x});
      addTearDown(h.close);
      final first = await h.coordinator.confirm(h.review, operationId: 'first');
      final original = (await h.app.drafts.get(h.review.draftId))!;
      final copy = original.copyWith(id: h.app.ids.next());
      await h.app.drafts.save(copy, expectedRevision: -1);
      final reviewed = await h.reviewDraft(copy);
      await expectLater(
        h.coordinator.confirm(reviewed, operationId: 'first'),
        throwsStateError,
      );
      final second = await h.coordinator.confirm(
        reviewed,
        operationId: 'explicit-new-draft',
      );
      expect(second, isNot(first));
      expect(h.x.createCount, 2);
      expect(h.x.sent.map((p) => p.content.text).toList(), [
        'Frozen caption',
        'Frozen caption',
      ]);
    },
  );

  test('a committed successful receipt survives an acknowledgment failure unchanged', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    final repository = ReceiptAcknowledgmentLostRepository(
      h.app.database,
      h.clock,
      h.app.ids,
    );
    final group = await h
        .makeCoordinator(repository: repository)
        .confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    expect(repository.lost, isTrue);
    expect(attempt.outcome.status, PublishStatus.published);
    expect(attempt.outcome.source, EvidenceSource.provider);
    expect(attempt.outcome.remoteId, '1234567890');
    expect(h.x.createCount, 1);
  });

  test('invalid provider receipt never becomes a trusted Unknown reconciliation hint', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    h.x.onSend = (post, context) async {
      await context.markDispatch();
      h.x.createCount++;
      return PublishOutcome(
        status: PublishStatus.published,
        source: EvidenceSource.provider,
        at: h.clock.now(),
        remoteId: 'invalid-x-id',
      );
    };
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final attempt = (await h.attempts.attempts(group)).single;
    expect(attempt.outcome.status, PublishStatus.unknown);
    expect(attempt.outcome.remoteId, isNull);
    expect(attempt.outcome.url, isNull);
  });

  test(
    'confirmed older Unknown blocks retry of its newer failed child',
    () async {
      final h = await coordinatorHarness(
        x: [
          PublishStatus.unknown,
          PublishStatus.notPublished,
          PublishStatus.published,
        ],
        selected: {Destination.x},
      );
      addTearDown(h.close);
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      final root = (await h.attempts.attempts(group)).single;
      final child = await h.coordinator.resendAfterCheck(
        root.id,
        h.review,
        operationId: 'risk',
        duplicateRiskAccepted: true,
      );
      h.x.onCheck = (post, previous, context) async {
        expect(post.content.text, 'Frozen caption');
        return h.x.outcome(PublishStatus.published);
      };
      await h.coordinator.check(root.id);
      await expectLater(
        h.coordinator.retry(
          child,
          h.review,
          operationId: 'after-original-found',
        ),
        throwsStateError,
      );
      expect(h.x.sent.length, 2);
      expect(
        (await h.attempts.getAttempt(root.id))!.outcome.status,
        PublishStatus.published,
      );
    },
  );

  test('confirmed older Unknown blocks a pending child claim without changing its frozen edit', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final root = (await h.attempts.attempts(group)).single;
    final child = (await h.attempts.createChild(
      root.id,
      h.review,
      'child-before-send',
      allowUnknown: true,
    )).attempt;
    h.x.onCheck = (post, previous, context) async =>
        h.x.outcome(PublishStatus.published);
    await h.coordinator.check(root.id);
    await h.coordinator.continuePending(
      group,
      h.review,
      attemptIds: {child.id},
    );
    expect(h.x.sent.length, 1);
    expect(
      (await h.attempts.getAttempt(child.id))!.outcome.status,
      PublishStatus.pending,
    );
  });

  test('older Unknown resolving during child preparation blocks its final dispatch and preserves edited content', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final root = (await h.attempts.attempts(group)).single;
    final draft = (await h.app.drafts.get(h.review.draftId))!;
    final edited = editOwnCaption(
      draft,
      Destination.x,
      'Preserved child edit',
      h.clock.now(),
    );
    await h.app.drafts.save(edited, expectedRevision: draft.revision);
    final reviewed = await h.reviewDraft(edited);
    final entered = Completer<void>();
    final finish = Completer<void>();
    h.x.onSend = (post, context) async {
      expect(post.content.text, 'Preserved child edit');
      await context.saveUpload('opaque-preparation', 'retained');
      entered.complete();
      await finish.future;
      await context.markDispatch();
      h.x.createCount++;
      return h.x.outcome(PublishStatus.published);
    };
    final retrying = h.coordinator.resendAfterCheck(
      root.id,
      reviewed,
      operationId: 'risk',
      duplicateRiskAccepted: true,
    );
    await entered.future;
    h.x.onCheck = (post, previous, context) async {
      expect(post.content.text, 'Frozen caption');
      return h.x.outcome(PublishStatus.published);
    };
    await h.coordinator.check(root.id);
    finish.complete();
    final child = (await h.attempts.getAttempt(await retrying))!;
    expect(h.x.createCount, 1);
    expect(child.dispatchAt, isNull);
    expect(child.outcome.status, PublishStatus.notPublished);
    expect(child.snapshot.content.text, 'Preserved child edit');
    expect(child.uploadState, {'opaque-preparation': 'retained'});
    final effective = (await h.attempts.effectiveAttempts(group)).single;
    expect(effective.id, root.id);
    expect(effective.snapshot.content.text, 'Frozen caption');
    expect((await h.attempts.attempts(group)).length, 2);
  });

  test('a child already dispatched preserves uncertainty when an older check resolves', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final root = (await h.attempts.attempts(group)).single;
    final dispatched = Completer<void>();
    final finish = Completer<void>();
    h.x.onSend = (post, context) async {
      await context.markDispatch();
      h.x.createCount++;
      dispatched.complete();
      await finish.future;
      return h.x.outcome(PublishStatus.unknown);
    };
    final retrying = h.coordinator.resendAfterCheck(
      root.id,
      h.review,
      operationId: 'risk',
      duplicateRiskAccepted: true,
    );
    await dispatched.future;
    h.x.onCheck = (post, previous, context) async =>
        h.x.outcome(PublishStatus.published);
    await h.coordinator.check(root.id);
    finish.complete();
    final child = (await h.attempts.getAttempt(await retrying))!;
    expect(child.outcome.status, PublishStatus.unknown);
    expect(child.dispatchAt, isNotNull);
    expect(h.x.createCount, 2);
    expect((await h.attempts.effectiveAttempts(group)).single.id, root.id);
    expect((await h.attempts.attempts(group)).length, 2);
  });

  test('effective destination result keeps unresolved leaf and user-reported winning source', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.notPublished, PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(h.review, operationId: 'first');
    final root = (await h.attempts.attempts(group)).single;
    final child = await h.coordinator.retry(
      root.id,
      h.review,
      operationId: 'retry',
    );
    expect((await h.attempts.effectiveAttempts(group)).single.id, child);
    await h.coordinator.reportFound(child);
    final winner = (await h.attempts.effectiveAttempts(group)).single;
    expect(winner.id, child);
    expect(winner.outcome.status, PublishStatus.userReported);
    expect(winner.snapshot.content.text, 'Frozen caption');
  });
}
