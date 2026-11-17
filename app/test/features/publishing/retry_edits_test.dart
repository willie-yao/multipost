import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:cross_posting_app/features/publishing/retry_edits.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coordinator_fixture.dart';

void main() {
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
  test('retry edit survives repository recreation and only sends its failed destination', () async {
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
  });

  test('retry context cannot authorize another parent and never accepts unknown by default', () async {
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
