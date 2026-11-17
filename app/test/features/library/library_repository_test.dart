import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/library/library_repository.dart';
import 'package:cross_posting_app/features/publishing/attempt.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coordinator_fixture.dart';

void main() {
  test('linked Instagram mark and persistent Undo move one retained group between attention and results', () async {
    final h = await coordinatorHarness(bluesky: [PublishStatus.published]);
    addTearDown(h.close);
    final id = await h.coordinator.confirm(h.review, operationId: 'original');
    final library = LibraryRepository(
      h.app.drafts,
      h.app.instagramRepo,
      attempts: h.attempts,
    );
    final prep = (await h.attempts.instagramPreparation(id))!;
    await h.instagram.markPosted(prep.packageId!);
    expect(await library.listAttention(), isEmpty);
    expect(await library.markedInstagram(), isEmpty);
    expect(await library.listGroups(), hasLength(1));
    await h.app.drafts.setDeleted(h.review.draftId, h.clock.now());
    await h.instagram.undoMarked(prep.packageId!);
    expect((await library.listAttention()).single.group!.id, id);
    expect(await library.pendingInstagram(), isEmpty);
    expect(
      (await h.attempts.instagramPreparation(id))!.packageId,
      prep.packageId,
    );
    expect(h.instagram.prepareCount, 1);
  });
  test('attention keeps one group in destination order and linked Instagram never becomes a second row', () async {
    final h = await coordinatorHarness();
    addTearDown(h.close);
    final id = await h.coordinator.confirm(h.review, operationId: 'original');
    final library = LibraryRepository(
      h.app.drafts,
      h.app.instagramRepo,
      attempts: h.attempts,
    );
    final attention = await library.listAttention();
    expect(attention, hasLength(1));
    expect(attention.single.group!.id, id);
    expect(attention.single.destinations, [
      Destination.x,
      Destination.bluesky,
      Destination.instagram,
    ]);
    expect(await library.pendingInstagram(), isEmpty);
    expect(await library.listDrafts(), isEmpty);
    await h.app.drafts.setDeleted(h.review.draftId, h.clock.now());
    expect((await library.listAttention()).single.group!.id, id);
    expect(await library.listGroups(), hasLength(1));
  });
}
