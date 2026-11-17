import 'dart:convert';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/features/publishing/publish_coordinator.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/retry_edits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coordinator_fixture.dart';
import '../../support/review_fixtures.dart';

void main() {
  test('retry source rejects noncanonical ownership and mismatched durable operation', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'original',
    );
    final parent = (await h.attempts.effectiveAttempts(group)).last;
    for (final source in [
      ('noncanonical', 'retry:${parent.id}'),
      ('retry:${parent.id}', 'wrong-operation'),
    ]) {
      final draft = Draft(
        id: source.$1,
        updatedAt: h.clock.now(),
        selected: {Destination.bluesky},
        shared: parent.snapshot.content,
        retryParentAttemptId: parent.id,
        retryOperationId: source.$2,
      );
      await h.app.drafts.save(draft, expectedRevision: -1);
      final reviewed = await h.reviewDraft(draft);
      await expectLater(
        h.attempts.createChild(parent.id, reviewed, source.$2),
        throwsArgumentError,
      );
      await h.app.database.db.delete(
        'drafts',
        where: 'id = ?',
        whereArgs: [draft.id],
      );
    }
    final draft = await RetryEdits(
      h.app.drafts,
      h.attempts,
      h.clock,
    ).open(parent.id);
    final reviewed = await h.reviewDraft(draft);
    final child = (await h.attempts.createChild(
      parent.id,
      reviewed,
      draft.retryOperationId!,
    )).attempt;
    for (final mutation in <Map<String, Object?>>[
      {'retry_operation': 'mismatched-operation'},
      {
        'parent_id': child.id,
        'payload': jsonEncode(child.copyWith(parentId: child.id).toJson()),
      },
      {
        'review_payload': jsonEncode(
          reviewed.copyWith(draftId: 'retry:someone-else').toJson(),
        ),
      },
      {
        'review_payload': jsonEncode(
          reviewed
              .copyWith(capabilityVersions: {Destination.bluesky: ''})
              .toJson(),
        ),
      },
      {
        'review_payload': jsonEncode(
          reviewed
              .copyWith(
                posts: {
                  Destination.bluesky: reviewed.posts[Destination.bluesky]!
                      .copyWith(content: PostContent(text: 'Replacement')),
                },
              )
              .toJson(),
        ),
      },
    ]) {
      await h.app.database.db.update(
        'destination_attempts',
        mutation,
        where: 'id = ?',
        whereArgs: [child.id],
      );
      await expectLater(
        h.attempts.reviewForAttempt(child.id),
        throwsFormatException,
      );
      await h.app.database.db.update(
        'destination_attempts',
        {
          'parent_id': parent.id,
          'payload': jsonEncode(child.toJson()),
          'retry_operation': draft.retryOperationId,
          'review_payload': jsonEncode(reviewed.toJson()),
        },
        where: 'id = ?',
        whereArgs: [child.id],
      );
    }
    // The durable canonical source remains usable even after physical deletion.
    await h.app.database.db.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [draft.id],
    );
    expect((await h.attempts.reviewForAttempt(child.id)).posts, reviewed.posts);
  });

  for (final processing in [false, true]) {
    test(
      'retry-owned frozen child continues after reopen from ${processing ? 'preparation-ready' : 'interrupted pending'}',
      () async {
        final h = await coordinatorHarness();
        addTearDown(h.close);
        final group = await h.coordinator.confirm(
          h.review,
          operationId: 'original',
        );
        final parent = (await h.attempts.effectiveAttempts(group)).last;
        final draft = await RetryEdits(
          h.app.drafts,
          h.attempts,
          h.clock,
        ).open(parent.id);
        final replacement = await photo(
          h.app.media.root,
          h.app.media.importFile,
          'retry-own',
        );
        final edited = editOwnMedia(
          editOwnCaption(
            draft,
            Destination.bluesky,
            'Frozen retry caption',
            h.clock.now(),
          ),
          Destination.bluesky,
          [Attachment(assetId: replacement.id, altText: 'Frozen retry photo')],
          h.clock.now(),
        );
        await h.app.drafts.save(edited, expectedRevision: draft.revision);
        h.directValidator.versionValue = 'retry-capability';
        final reviewed = await h.reviewDraft(edited);
        late String childId;
        if (processing) {
          h.bluesky.onSend = (post, context) async {
            await context.saveUpload('opaque-upload', 'processing');
            return h.bluesky.outcome(PublishStatus.processing);
          };
          childId = await h.coordinator.retry(
            parent.id,
            reviewed,
            operationId: draft.retryOperationId!,
          );
        } else {
          childId = (await h.attempts.createChild(
            parent.id,
            reviewed,
            draft.retryOperationId!,
          )).attempt.id;
          expect(await h.attempts.claim(childId), isTrue);
          await h.attempts.saveUpload(childId, 'opaque-upload', 'ready');
        }
        // Neither later editable content nor tombstoning may replace frozen bytes.
        await h.app.drafts.save(
          editOwnCaption(
            edited,
            Destination.bluesky,
            'Later unreviewed content',
            h.clock.now(),
          ),
          expectedRevision: edited.revision,
        );
        await h.app.drafts.setDeleted(draft.id, h.clock.now());
        final path = h.app.database.db.path;
        await h.app.database.close();
        final database = await LocalDatabase.open(
          databaseFactoryFfiNoIsolate,
          path,
        );
        final app = AppServices(
          database: database,
          media: MediaFiles(database, h.app.media.root, h.app.ids),
          drafts: SqliteDraftRepository(database),
          accounts: LocalAccountRepository(database),
          instagramPackageRoot: h.app.instagramPackageRoot,
          clock: h.clock,
          ids: h.app.ids,
        );
        addTearDown(app.close);
        final reopenedInstagram = CountedInstagram(app, h.clock);
        final coordinator = PublishCoordinator(
          attempts: app.attempts,
          review: ReviewService(
            app.drafts,
            app.media,
            app.accounts,
            h.validators,
            h.clock,
          ),
          instagram: reopenedInstagram,
          providers: {Destination.x: h.x, Destination.bluesky: h.bluesky},
          clock: h.clock,
          directOnline: () => true,
        );
        await app.attempts.recoverInterrupted();
        final beforeSends = h.bluesky.sent.length;
        expect(h.x.sent, hasLength(1));
        expect(h.instagram.prepareCount, 1);
        if (processing) {
          h.bluesky.onCheck = (post, previous, context) async {
            expect(post, reviewed.posts[Destination.bluesky]);
            await context.saveUpload('opaque-upload', 'ready');
            return PublishOutcome(
              status: PublishStatus.processing,
              source: EvidenceSource.local,
              at: h.clock.now(),
              reasonCode: 'preparation-ready',
            );
          };
          await coordinator.check(childId);
          expect(h.bluesky.sent, hasLength(beforeSends));
        }
        final frozen = await app.attempts.reviewForAttempt(childId);
        expect(frozen.draftId, draft.id);
        expect(frozen.posts, reviewed.posts);
        expect(
          frozen.capabilityVersions[Destination.bluesky],
          'retry-capability',
        );
        h.bluesky.onSend = (post, context) async {
          expect(post, reviewed.posts[Destination.bluesky]);
          expect(context.uploadState, {'opaque-upload': 'ready'});
          await context.markDispatch();
          h.bluesky.createCount++;
          return h.bluesky.outcome(PublishStatus.published);
        };
        await coordinator.continuePending(group, frozen, attemptIds: {childId});
        expect(
          (await app.attempts.getAttempt(childId))!.outcome.status,
          PublishStatus.published,
        );
        expect(h.bluesky.sent, hasLength(beforeSends + 1));
        expect(h.x.sent, hasLength(1));
        expect(h.instagram.prepareCount, 1);
        expect(reopenedInstagram.prepareCount, 0);
        expect((await app.attempts.getGroup(group))!.snapshot, h.review);
      },
    );
  }

  test('saved retry context is immutable, paired and soft-deleted edits are resumed', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'original',
    );
    final parent = (await h.attempts.effectiveAttempts(group)).last;
    final edits = RetryEdits(h.app.drafts, h.attempts, h.clock);
    final draft = await edits.open(parent.id);
    final edited = editOwnCaption(
      draft,
      Destination.bluesky,
      'Do not lose this edit',
      h.clock.now(),
    );
    await h.app.drafts.save(edited, expectedRevision: draft.revision);
    await h.app.drafts.setDeleted(draft.id, h.clock.now());
    final restored = await edits.open(parent.id);
    expect(restored.deletedAt, isNull);
    expect(
      restored.versions[Destination.bluesky]!.ownText,
      'Do not lose this edit',
    );
    await expectLater(
      h.app.drafts.save(
        restored.copyWith(
          revision: restored.revision + 1,
          retryParentAttemptId: null,
          retryOperationId: null,
        ),
        expectedRevision: restored.revision,
      ),
      throwsA(isA<Exception>()),
    );
    final ordinary = Draft(id: 'ordinary', updatedAt: h.clock.now());
    await h.app.drafts.save(ordinary, expectedRevision: -1);
    await expectLater(
      h.app.drafts.save(
        ordinary.copyWith(
          revision: 1,
          retryParentAttemptId: parent.id,
          retryOperationId: 'new',
        ),
        expectedRevision: 0,
      ),
      throwsA(isA<Exception>()),
    );
    final malformed = Draft(
      id: 'unpaired',
      updatedAt: h.clock.now(),
      retryParentAttemptId: parent.id,
    );
    await expectLater(
      h.app.drafts.save(malformed, expectedRevision: -1),
      throwsArgumentError,
    );
    expect(await h.app.drafts.get('unpaired'), isNull);
  });

  test('deterministic retry ID collision retains unrelated draft and refuses adoption', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'original',
    );
    final parent = (await h.attempts.effectiveAttempts(group)).last;
    final existing = Draft(
      id: 'retry:${parent.id}',
      updatedAt: h.clock.now(),
      shared: PostContent(text: 'Unrelated retained words'),
    );
    await h.app.drafts.save(existing, expectedRevision: -1);
    await expectLater(
      RetryEdits(h.app.drafts, h.attempts, h.clock).open(parent.id),
      throwsStateError,
    );
    expect(await h.app.drafts.get(existing.id), existing);
  });
  test(
    'saved retry edit reopens and only sends its failed destination',
    () async {
      final h = await coordinatorHarness();
      addTearDown(h.close);
      final group = await h.coordinator.confirm(
        h.review,
        operationId: 'original',
      );
      final parent = (await h.attempts.effectiveAttempts(group)).last;
      final edits = RetryEdits(h.app.drafts, h.attempts, h.clock);
      final context = await edits.open(parent.id);
      final draft = (await h.app.drafts.get(context.id))!;
      expect(draft.id, isNot(h.review.draftId));
      expect(draft.selected, {Destination.bluesky});
      final edited = editOwnCaption(
        draft,
        Destination.bluesky,
        'Edited failure only',
        h.clock.now(),
      );
      await h.app.drafts.save(edited, expectedRevision: draft.revision);
      final restored = await h.app.drafts.get(draft.id);
      expect(restored!.retryParentAttemptId, parent.id);
      expect((await edits.open(parent.id)).id, draft.id);
      final reviewed = await h.reviewDraft(edited);
      await expectLater(
        h.coordinator.confirm(reviewed, operationId: 'wrong-route'),
        throwsStateError,
      );
      final child = await h.coordinator.retry(
        parent.id,
        reviewed,
        operationId: context.retryOperationId!,
      );
      expect(
        (await h.attempts.getAttempt(child))!.snapshot.content.text,
        'Edited failure only',
      );
      expect(h.x.sent, hasLength(1));
      expect(h.bluesky.sent, hasLength(2));
      expect(h.instagram.prepareCount, 1);
      expect(
        (await h.app.drafts.get(h.review.draftId))!.shared.text,
        'Frozen caption',
      );
      expect((await h.attempts.getGroup(group))!.snapshot, h.review);
    },
  );

  test('Unknown recovery rejects ordinary retry and requires explicit duplicate risk', () async {
    final h = await coordinatorHarness(bluesky: [PublishStatus.unknown]);
    addTearDown(h.close);
    final group = await h.coordinator.confirm(
      h.review,
      operationId: 'original',
    );
    final parent = (await h.attempts.effectiveAttempts(group)).last;
    final edits = RetryEdits(h.app.drafts, h.attempts, h.clock);
    final context = await edits.open(parent.id);
    final reviewed = await h.reviewDraft((await h.app.drafts.get(context.id))!);
    await expectLater(
      h.coordinator.retry(
        parent.id,
        reviewed,
        operationId: context.retryOperationId!,
      ),
      throwsStateError,
    );
    await expectLater(
      h.coordinator.resendAfterCheck(
        parent.id,
        reviewed,
        operationId: context.retryOperationId!,
        duplicateRiskAccepted: false,
      ),
      throwsStateError,
    );
    expect(h.bluesky.sent, hasLength(1));
    expect(
      (await h.app.drafts.get(context.id))!.retryParentAttemptId,
      parent.id,
    );
  });
}
