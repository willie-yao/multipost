import 'dart:convert';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/review/review.dart';
import 'package:cross_posting_app/features/review/review_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';
import '../../support/review_fixtures.dart';

void main() {
  test(
    'review keeps disconnected selections and blocks direct publishing',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final d = sampleDraft();
      await s.drafts.save(d, expectedRevision: -1);
      final result = await ReviewService(
        s.drafts,
        s.media,
        s.accounts,
        const LocalValidators(),
        s.clock,
      ).review(d);
      expect(result.snapshot.posts.keys.toSet(), d.selected);
      expect(result.canProceed, isFalse);
      expect(
        result.issues.any(
          (i) =>
              i.destination == Destination.bluesky &&
              // Bluesky is switched off in this build, so Review says so
              // instead of asking for a connection that cannot be made.
              i.code == 'not-available',
        ),
        isTrue,
      );
      expect(
        result.issues.where((i) => i.code == 'requirements-unverified').length,
        3,
      );
    },
  );

  test(
    'snapshots own exact resolved captions media order descriptions and JSON',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final a = await photo(s.media.root, s.media.importFile, 'a');
      final b = await photo(s.media.root, s.media.importFile, 'b');
      final d = sampleDraft().copyWith(
        shared: PostContent(
          text: 'shared words',
          media: [
            Attachment(assetId: a.id, altText: 'first description'),
            Attachment(assetId: b.id),
          ],
        ),
        versions: {
          Destination.bluesky: DestinationVersion(ownText: 'own words'),
          Destination.instagram: DestinationVersion(
            ownMedia: [Attachment(assetId: b.id, altText: 'own description')],
          ),
        },
      );
      await s.drafts.save(d, expectedRevision: -1);
      final result = await ReviewService(
        s.drafts,
        s.media,
        s.accounts,
        const LocalValidators(),
        s.clock,
      ).review(d);
      expect(
        result.snapshot.posts[Destination.x]!.content.text,
        'shared words',
      );
      expect(
        result.snapshot.posts[Destination.bluesky]!.content.text,
        'own words',
      );
      expect(
        result.snapshot.posts[Destination.bluesky]!.assets.map((a) => a.id),
        [a.id, b.id],
      );
      expect(
        result.snapshot.posts[Destination.x]!.content.media.first.altText,
        'first description',
      );
      expect(
        result
            .snapshot
            .posts[Destination.instagram]!
            .content
            .media
            .single
            .altText,
        'own description',
      );
      expect(result.snapshot.posts[Destination.instagram]!.assets.single, b);
      final decoded = ReviewedPost.fromJson(
        jsonDecode(jsonEncode(result.snapshot.toJson()))
            as Map<String, dynamic>,
      );
      expect(decoded, result.snapshot);
      expect(() => decoded.posts.clear(), throwsUnsupportedError);
      final incoming = <MediaAsset>[a];
      final post = ResolvedPost(
        ownCaption: false,
        destination: Destination.x,
        content: PostContent(),
        assets: incoming,
      );
      incoming.clear();
      expect(post.assets, [a]);
      final posts = {Destination.x: post};
      final versions = {Destination.x: 'verified-1'};
      final owned = ReviewedPost(
        draftId: 'owned',
        revision: 1,
        posts: posts,
        capabilityVersions: versions,
        reviewedAt: DateTime.utc(2026),
      );
      posts.clear();
      versions.clear();
      expect(owned.posts.keys, [Destination.x]);
      expect(owned.capabilityVersions[Destination.x], 'verified-1');
    },
  );

  test('same-size damaged media and missing files block only affected destinations', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final a = await photo(s.media.root, s.media.importFile, 'a');
    final d = sampleDraft().copyWith(
      shared: PostContent(text: 'words'),
      versions: {
        Destination.instagram: DestinationVersion(
          ownMedia: [Attachment(assetId: a.id)],
        ),
      },
    );
    await s.drafts.save(d, expectedRevision: -1);
    final file = await s.media.fileFor(a.id);
    final bytes = await file.readAsBytes();
    bytes[bytes.length - 1] ^= 1;
    await file.writeAsBytes(bytes);
    final service = ReviewService(
      s.drafts,
      s.media,
      s.accounts,
      const LocalValidators(),
      s.clock,
    );
    final damaged = await service.review(d);
    expect(
      damaged.issues
          .where((i) => i.code == 'media-unavailable')
          .map((i) => i.destination),
      [Destination.instagram],
    );
    expect(damaged.snapshot.posts.keys.toSet(), d.selected);
    await file.delete();
    final missing = await service.review(d);
    expect(missing.issues.any((i) => i.code == 'media-unavailable'), isTrue);
    expect(missing.canProceed, isFalse);
  });

  test(
    'empty content mixtures multiple videos and Instagram video remain blocked',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final a = await photo(s.media.root, s.media.importFile, 'photo');
      final video = await syntheticVideo(s.media.root, s.database.db.insert);
      final d = sampleDraft().copyWith(
        shared: PostContent(
          media: [
            Attachment(assetId: video.id),
            Attachment(assetId: a.id),
            Attachment(assetId: video.id),
          ],
        ),
        versions: {Destination.x: DestinationVersion(ownMedia: [])},
      );
      await s.drafts.save(d, expectedRevision: -1);
      final result = await ReviewService(
        s.drafts,
        s.media,
        s.accounts,
        const LocalValidators(),
        s.clock,
      ).review(d);
      expect(
        result.issues.any(
          (i) => i.destination == Destination.x && i.code == 'empty-post',
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (i) =>
              i.destination == Destination.bluesky && i.code == 'mixed-media',
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (i) =>
              i.destination == Destination.bluesky &&
              i.code == 'multiple-videos',
        ),
        isTrue,
      );
      expect(
        result.issues.any(
          (i) =>
              i.destination == Destination.instagram &&
              i.code == 'instagram-photos-only',
        ),
        isTrue,
      );
      expect(result.snapshot.posts[Destination.instagram]!.assets.length, 3);
      expect(d.shared.media.first.assetId, video.id);
    },
  );

  test(
    'unavailable account and validator checks never infer readiness',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final d = sampleDraft();
      await s.drafts.save(d, expectedRevision: -1);
      final accounts = ReviewAccounts()..fail = true;
      final result = await ReviewService(
        s.drafts,
        s.media,
        accounts,
        TestValidators(throwsOnValidate: true),
        s.clock,
      ).review(d, directOnline: true);
      expect(result.snapshot.posts.length, 3);
      expect(
        result.issues.where((i) => i.code == 'validation-unavailable').length,
        greaterThanOrEqualTo(3),
      );
      expect(result.canProceed, isFalse);
    },
  );

  test(
    'offline blocks direct destinations while verified Instagram is local',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final a = await photo(s.media.root, s.media.importFile, 'photo');
      final d = sampleDraft().copyWith(
        shared: PostContent(media: [Attachment(assetId: a.id)]),
      );
      await s.drafts.save(d, expectedRevision: -1);
      final service = ReviewService(
        s.drafts,
        s.media,
        ReviewAccounts(),
        TestValidators(),
        s.clock,
      );
      final offline = await service.review(d, directOnline: false);
      expect(
        offline.issues
            .where((i) => i.code == 'offline')
            .map((i) => i.destination)
            .toSet(),
        {Destination.x, Destination.bluesky},
      );
      expect(
        offline.issues.where((i) => i.destination == Destination.instagram),
        isEmpty,
      );
      final local = d.copyWith(
        id: 'instagram-only',
        selected: {Destination.instagram},
      );
      await s.drafts.save(local, expectedRevision: -1);
      expect(
        (await service.review(local, directOnline: false)).canProceed,
        isTrue,
      );
      final unknown = await service.review(d);
      expect(
        unknown.issues.where((i) => i.code == 'connectivity-unverified').length,
        2,
      );
      expect(unknown.canProceed, isFalse);
    },
  );

  test('no selected destinations cannot proceed even without issues', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final d = sampleDraft().copyWith(selected: {});
    await s.drafts.save(d, expectedRevision: -1);
    final result = await ReviewService(
      s.drafts,
      s.media,
      s.accounts,
      TestValidators(),
      s.clock,
    ).review(d);
    expect(result.snapshot.posts, isEmpty);
    expect(result.canProceed, isFalse);
  });

  test(
    'revalidation rejects persisted edits and selected identity changes',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final d = sampleDraft().copyWith(selected: {Destination.x});
      await s.drafts.save(d, expectedRevision: -1);
      final accounts = ReviewAccounts();
      final service = ReviewService(
        s.drafts,
        s.media,
        accounts,
        TestValidators(),
        s.clock,
      );
      final first = await service.review(d, directOnline: true);
      accounts.subject = 'another-person';
      await expectLater(
        service.revalidate(first.snapshot, d, directOnline: true),
        throwsA(isA<StaleReviewException>()),
      );
      accounts.subject = 'person';
      final next = editSharedCaption(d, 'new persisted words', s.clock.now());
      await s.drafts.save(next, expectedRevision: d.revision);
      await expectLater(
        service.revalidate(first.snapshot, d, directOnline: true),
        throwsA(isA<StaleReviewException>()),
      );
    },
  );

  test(
    'revalidation reruns current policy and connection validation',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final d = sampleDraft().copyWith(selected: {Destination.x});
      await s.drafts.save(d, expectedRevision: -1);
      final accounts = ReviewAccounts();
      final validators = TestValidators();
      final service = ReviewService(
        s.drafts,
        s.media,
        accounts,
        validators,
        s.clock,
      );
      final first = await service.review(d, directOnline: true);
      expect(first.canProceed, isTrue);
      accounts.expired = true;
      final expired = await service.revalidate(
        first.snapshot,
        d,
        directOnline: true,
      );
      expect(expired.canProceed, isFalse);
      expect(expired.issues.any((i) => i.code == 'connection-expired'), isTrue);
      accounts.expired = false;
      validators.block = true;
      expect(
        (await service.revalidate(
          first.snapshot,
          d,
          directOnline: true,
        )).canProceed,
        isFalse,
      );
      validators.versionValue = 'verified-2';
      await expectLater(
        service.revalidate(first.snapshot, d, directOnline: true),
        throwsA(isA<StaleReviewException>()),
      );
    },
  );

  test('action labels describe exact selected destinations', () {
    expect(reviewActionLabel({Destination.instagram}), 'Prepare Instagram');
    expect(
      reviewActionLabel({Destination.x, Destination.instagram}),
      'Publish & prepare',
    );
    expect(reviewActionLabel({Destination.x}), 'Publish to X');
    expect(reviewActionLabel({Destination.bluesky}), 'Publish to Bluesky');
    expect(
      reviewActionLabel({Destination.x, Destination.bluesky}),
      'Publish to 2 accounts',
    );
  });
}
