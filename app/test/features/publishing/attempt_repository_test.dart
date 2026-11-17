import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'dart:convert';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/attempt_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coordinator_fixture.dart';

void main() {
  test(
    'begin freezes owned rows and deduplicates operation and draft revision',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      final first = await h.attempts.begin(h.review, 'first');
      final repeated = await h.attempts.begin(h.review, 'first');
      final sameRevision = await h.attempts.begin(h.review, 'other');
      expect(first.created, isTrue);
      expect(repeated.created, isFalse);
      expect(sameRevision.created, isFalse);
      expect(sameRevision.group.id, first.group.id);
      final rows = await h.attempts.attempts(first.group.id);
      expect(rows.length, 2);
      expect(
        rows.every(
          (a) =>
              a.outcome.status == PublishStatus.pending &&
              a.uploadState.isEmpty,
        ),
        isTrue,
      );
      expect(
        (await h.attempts.instagramPreparation(first.group.id))!.state,
        InstagramPreparationState.pending,
      );
      final decoded = AttemptGroup.fromJson(
        jsonDecode(jsonEncode(first.group.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.snapshot, h.review);
      final restored = DestinationAttempt.fromJson(
        jsonDecode(jsonEncode(rows.first.toJson())) as Map<String, dynamic>,
      );
      expect(restored.snapshot, rows.first.snapshot);
      expect(
        () => restored.uploadState['changed'] = 'true',
        throwsUnsupportedError,
      );
    },
  );

  test(
    'two repository instances claim once and dispatch is durable exactly once',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      final group = await h.attempts.begin(h.review, 'first');
      final attempt = (await h.attempts.attempts(group.group.id)).first;
      final other = AttemptRepository(h.app.database, h.clock, h.app.ids);
      expect(
        await Future.wait([
          h.attempts.claim(attempt.id),
          other.claim(attempt.id),
        ]),
        containsAll([true, false]),
      );
      final projection = (await h.app.database.db.query(
        'destination_attempts',
        where: 'id = ?',
        whereArgs: [attempt.id],
      )).single;
      expect(projection['state'], 'preparing');
      expect(
        (jsonDecode(projection['payload'] as String)['outcome']
            as Map)['status'],
        'preparing',
      );
      await h.attempts.saveUpload(
        attempt.id,
        'opaque-media-evidence',
        'retained',
      );
      await h.attempts.markDispatch(attempt.id);
      await expectLater(other.markDispatch(attempt.id), throwsStateError);
      final dispatched = (await h.attempts.getAttempt(attempt.id))!;
      expect(dispatched.dispatchAt, h.clock.now());
      expect(dispatched.outcome.status, PublishStatus.sending);
      expect(
        (await h.app.database.db.query(
          'attempt_events',
          where: 'attempt_id = ?',
          whereArgs: [attempt.id],
        )).length,
        4,
      );
    },
  );

  test('interrupted preparation retains uploads and interrupted dispatch becomes unknown', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'first');
    final rows = await h.attempts.attempts(group.group.id);
    for (final row in rows) {
      await h.attempts.claim(row.id);
    }
    await h.attempts.saveUpload(rows.first.id, 'opaque', 'saved');
    await h.attempts.markDispatch(rows.last.id);
    await h.attempts.claimInstagram(group.group.id);
    final reopened = AttemptRepository(h.app.database, h.clock, h.app.ids);
    await reopened.recoverInterrupted();
    final unsent = (await reopened.getAttempt(rows.first.id))!;
    expect(unsent.outcome.status, PublishStatus.pending);
    expect(unsent.uploadState, {'opaque': 'saved'});
    expect(
      (await reopened.getAttempt(rows.last.id))!.outcome.status,
      PublishStatus.unknown,
    );
    expect(
      (await reopened.instagramPreparation(group.group.id))!.state,
      InstagramPreparationState.pending,
    );
    expect(h.x.sent, isEmpty);
    expect(h.bluesky.sent, isEmpty);
  });

  test(
    'begin transaction rolls back every row when destination insertion fails',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      await h.app.database.db.execute(
        "CREATE TRIGGER reject_begin BEFORE INSERT ON destination_attempts BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        h.coordinator.confirm(h.review, operationId: 'fail'),
        throwsA(anything),
      );
      expect(await h.app.database.db.query('attempt_groups'), isEmpty);
      expect(await h.app.database.db.query('attempt_events'), isEmpty);
      expect(h.x.sent, isEmpty);
      expect(h.instagram.prepareCount, 0);
    },
  );

  test('provider receipts and completed projections cannot be forged or overwritten', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'first');
    final attempt = (await h.attempts.attempts(group.group.id)).single;
    await h.attempts.claim(attempt.id);
    await h.attempts.markDispatch(attempt.id);
    await expectLater(
      h.attempts.record(
        attempt.id,
        PublishOutcome(
          status: PublishStatus.published,
          source: EvidenceSource.provider,
          at: h.clock.now(),
          remoteId: 'not-an-x-id',
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      h.attempts.record(
        attempt.id,
        PublishOutcome(
          status: PublishStatus.userReported,
          source: EvidenceSource.user,
          at: h.clock.now(),
        ),
      ),
      throwsArgumentError,
    );
    await h.attempts.record(attempt.id, h.x.outcome(PublishStatus.published));
    await expectLater(
      h.attempts.record(attempt.id, h.x.outcome(PublishStatus.notPublished)),
      throwsStateError,
    );
    await expectLater(
      h.attempts.saveUpload(attempt.id, 'late', 'overwrite'),
      throwsStateError,
    );
    expect(
      (await h.attempts.getAttempt(attempt.id))!.outcome.status,
      PublishStatus.published,
    );
  });

  test(
    'begin and child commit reject a saved revision changed after validation',
    () async {
      final h = await coordinatorHarness(selected: {Destination.x});
      addTearDown(h.close);
      final draft = (await h.app.drafts.get(h.review.draftId))!;
      await h.app.drafts.save(
        editSharedCaption(draft, 'Changed before begin commit', h.clock.now()),
        expectedRevision: draft.revision,
      );
      await expectLater(
        h.attempts.begin(h.review, 'stale-begin'),
        throwsA(anything),
      );
      expect(await h.app.database.db.query('attempt_groups'), isEmpty);
      final changed = (await h.app.drafts.get(h.review.draftId))!;
      final reviewed = await h.reviewDraft(changed);
      final group = await h.attempts.begin(reviewed, 'current');
      final parent = (await h.attempts.attempts(group.group.id)).single;
      await h.attempts.claim(parent.id);
      await h.attempts.record(
        parent.id,
        h.x.outcome(PublishStatus.notPublished),
      );
      await h.app.drafts.save(
        editSharedCaption(
          changed,
          'Changed before child commit',
          h.clock.now(),
        ),
        expectedRevision: changed.revision,
      );
      await expectLater(
        h.attempts.createChild(parent.id, reviewed, 'stale-retry'),
        throwsA(anything),
      );
      expect((await h.attempts.attempts(group.group.id)).length, 1);
    },
  );

  test('close and reopen recovers durable dispatch and preserves all earlier events', () async {
    final h = await coordinatorHarness(selected: {Destination.x});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'first');
    final attempt = (await h.attempts.attempts(group.group.id)).single;
    await h.attempts.claim(attempt.id);
    await h.attempts.saveUpload(attempt.id, 'opaque-evidence', 'saved');
    await h.attempts.markDispatch(attempt.id);
    final path = h.app.database.db.path;
    final before = await h.app.database.db.query(
      'attempt_events',
      orderBy: 'seq',
    );
    await h.app.database.close();
    final reopened = await LocalDatabase.open(
      databaseFactoryFfiNoIsolate,
      path,
    );
    addTearDown(reopened.close);
    final repository = AttemptRepository(reopened, h.clock, h.app.ids);
    await repository.recoverInterrupted();
    final recovered = (await repository.getAttempt(attempt.id))!;
    expect(recovered.outcome.status, PublishStatus.unknown);
    expect(recovered.uploadState, {'opaque-evidence': 'saved'});
    expect(recovered.dispatchAt, h.clock.now());
    final events = await reopened.db.query('attempt_events', orderBy: 'seq');
    expect(events.take(before.length).toList(), before);
    expect(events.length, before.length + 1);
    expect(h.x.sent, isEmpty);
  });

  test(
    'a check cannot downgrade unknown publication into a safe ordinary failure',
    () async {
      final h = await coordinatorHarness(
        x: [PublishStatus.unknown],
        selected: {Destination.x},
      );
      addTearDown(h.close);
      final group = await h.coordinator.confirm(h.review, operationId: 'first');
      final unknown = (await h.attempts.attempts(group)).single;
      h.x.onCheck = (post, previous, context) async =>
          h.x.outcome(PublishStatus.notPublished);
      await h.coordinator.check(unknown.id);
      expect(
        (await h.attempts.getAttempt(unknown.id))!.outcome.status,
        PublishStatus.unknown,
      );
    },
  );

  test(
    'a child source cannot resolve through a parent from another destination',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      final group = await h.attempts.begin(h.review, 'first');
      final roots = await h.attempts.attempts(group.group.id);
      await h.attempts.claim(roots.first.id);
      await h.attempts.record(
        roots.first.id,
        h.x.outcome(PublishStatus.notPublished),
      );
      final child = (await h.attempts.createChild(
        roots.first.id,
        h.review,
        'retry',
      )).attempt;
      await h.app.database.db.update(
        'destination_attempts',
        {
          'parent_id': roots.last.id,
          'payload': jsonEncode(
            child.copyWith(parentId: roots.last.id).toJson(),
          ),
        },
        where: 'id = ?',
        whereArgs: [child.id],
      );
      await expectLater(
        h.attempts.reviewForAttempt(child.id),
        throwsFormatException,
      );
    },
  );

  test('receipt validation rejects wrong Bluesky author collection key and link', () async {
    final h = await coordinatorHarness(selected: {Destination.bluesky});
    addTearDown(h.close);
    final group = await h.attempts.begin(h.review, 'first');
    final attempt = (await h.attempts.attempts(group.group.id)).single;
    await h.attempts.claim(attempt.id);
    await h.attempts.markDispatch(attempt.id);
    for (final id in [
      'at://did:plc:zzzzzzzzzzzzzzzzzzzzzzzz/app.bsky.feed.post/3lbrt5aaa2222',
      'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.like/3lbrt5aaa2222',
      'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/not-a-tid',
    ]) {
      await expectLater(
        h.attempts.record(
          attempt.id,
          PublishOutcome(
            status: PublishStatus.published,
            source: EvidenceSource.provider,
            at: h.clock.now(),
            remoteId: id,
          ),
        ),
        throwsArgumentError,
      );
    }
    await expectLater(
      h.attempts.record(
        attempt.id,
        PublishOutcome(
          status: PublishStatus.published,
          source: EvidenceSource.provider,
          at: h.clock.now(),
          remoteId: 'at://did:plc:abcdefghijklmnopqrstuvwx/app.bsky.feed.post/3lbrt5aaa2222',
          url: Uri.parse(
            'https://bsky.app/profile/someone-else/post/3lbrt5aaa2222',
          ),
        ),
      ),
      throwsArgumentError,
    );
    await h.attempts.record(
      attempt.id,
      h.bluesky.outcome(PublishStatus.published),
    );
    expect(
      (await h.attempts.getAttempt(attempt.id))!.outcome.status,
      PublishStatus.published,
    );
  });

  test('manual found on a nonbusy Unknown ancestor fences a preparing child final dispatch', () async {
    final h = await coordinatorHarness(
      x: [PublishStatus.unknown],
      selected: {Destination.x},
    );
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'original',
    );
    final original = (await h.attempts.attempts(group)).single;
    final child = (await h.attempts.createChild(
      original.id,
      h.review,
      'child',
      allowUnknown: true,
    )).attempt;
    expect(await h.attempts.claim(child.id), isTrue);
    await h.attempts.saveUpload(child.id, 'opaque-preparation', 'retained');
    await h.attempts.reportFound(original.id);
    await expectLater(h.attempts.markDispatch(child.id), throwsStateError);
    expect((await h.attempts.getAttempt(child.id))!.dispatchAt, isNull);
    expect((await h.attempts.getAttempt(child.id))!.uploadState, {
      'opaque-preparation': 'retained',
    });
    expect((await h.attempts.effectiveAttempts(group)).single.id, original.id);
    expect(
      (await h.attempts.getAttempt(original.id))!.outcome.source,
      EvidenceSource.user,
    );
  });
}
