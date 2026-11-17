import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/instagram/instagram_package.dart';
import 'package:cross_posting_app/features/instagram/instagram_repository.dart';
import 'package:cross_posting_app/features/instagram/instagram_service.dart';
import 'package:cross_posting_app/features/library/library_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../support/instagram_fixture.dart';

void main() {
  test('production local preparation freezes an actual decoded JPEG', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final source = File(
      '${File(s.app.database.db.path).parent.path}/source.jpg',
    );
    await source.writeAsBytes(img.encodeJpg(img.Image(width: 15, height: 11)));
    final asset = await s.app.media.importFile(XFile(source.path));
    final draft = Draft(
      id: s.app.ids.next(),
      updatedAt: s.app.clock.now(),
      selected: {Destination.instagram},
      shared: PostContent(
        text: 'JPEG caption',
        media: [Attachment(assetId: asset.id, altText: 'JPEG description')],
      ),
    );
    await s.app.drafts.save(draft, expectedRevision: -1);
    final review = await s.app.review.review(draft);
    expect(review.canProceed, isTrue);
    final one = await s.app.instagram.prepare(
      review.snapshot,
      operationId: 'jpeg-production-policy',
    );
    final photo = one.photos.single;
    final frozen = await s.app.instagram.fileFor(one, photo);
    expect(photo.relativePath.endsWith('/01.jpg'), isTrue);
    expect(
      (await sha256.bind(frozen.openRead()).first).toString(),
      asset.sha256,
    );
    expect(one.caption, 'JPEG caption');
    expect(photo.altText, 'JPEG description');
  });

  test(
    'caption provenance is frozen even when shared and own words match',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final sharedReview = await s.reviewTwoPhotos('Identical words');
      final shared = await s.instagram.prepare(
        sharedReview,
        operationId: 'shared-origin',
      );
      expect(shared.ownCaption, isFalse);
      final post = sharedReview.posts[Destination.instagram]!;
      await expectLater(
        s.instagram.prepare(
          sharedReview.copyWith(
            posts: {Destination.instagram: post.copyWith(ownCaption: true)},
          ),
          operationId: 'shared-origin',
        ),
        throwsStateError,
      );
      final original = (await s.app.drafts.get(sharedReview.draftId))!;
      final edited = editOwnCaption(
        original,
        Destination.instagram,
        'Identical words',
        s.app.clock.now(),
      );
      await s.app.drafts.save(edited, expectedRevision: original.revision);
      final ownReview = (await s.review.review(edited)).snapshot;
      expect(ownReview.posts[Destination.instagram]!.ownCaption, isTrue);
      final own = await s.instagram.prepare(
        ownReview,
        operationId: 'own-origin',
      );
      expect(own.ownCaption, isTrue);
      await s.app.drafts.setDeleted(original.id, s.app.clock.now());
      await s.app.database.db.delete(
        'drafts',
        where: 'id = ?',
        whereArgs: [original.id],
      );
      expect((await s.instagramRepo.get(shared.id))!.ownCaption, isFalse);
      expect((await s.instagramRepo.get(own.id))!.ownCaption, isTrue);
    },
  );

  test('separate preparers converge on the DB operation key and discard only their loser', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final review = await s.reviewTwoPhotos('Caption');
    final second = InstagramService(
      s.instagramRepo,
      s.app.media,
      s.app.instagramPackageRoot,
      s.policy,
      s.app.ids,
      s.app.clock,
    );
    final packages = await Future.wait([
      s.instagram.prepare(review, operationId: 'race'),
      second.prepare(review, operationId: 'race'),
    ]);
    expect(packages[0].id, packages[1].id);
    expect(await s.instagramRepo.pending(), [packages[0]]);
    expect(await s.app.instagramPackageRoot.list().length, 1);
  });

  test(
    'missing frozen files are reported without rebuilding the same operation',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Caption');
      final one = await s.instagram.prepare(
        review,
        operationId: 'frozen-missing',
      );
      await (await s.instagram.fileFor(one, one.photos.last)).delete();
      await expectLater(
        s.instagram.prepare(review, operationId: 'frozen-missing'),
        throwsA(
          isA<InstagramPreparationException>().having(
            (e) => e.photoOrdinal,
            'affected photo',
            2,
          ),
        ),
      );
      expect(await s.instagramRepo.get(one.id), one);
      expect(await s.app.instagramPackageRoot.list().length, 1);
    },
  );

  test(
    'preparation pins reviewed words and reuses the same operation',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Reviewed caption');
      final results = await Future.wait(
        List.generate(
          4,
          (_) => s.instagram.prepare(review, operationId: 'prepare-1'),
        ),
      );
      final one = results.first;
      final two = await s.instagram.prepare(review, operationId: 'prepare-1');
      expect(results.map((p) => p.id).toSet(), {one.id});
      expect(two.id, one.id);
      expect(one.caption, 'Reviewed caption');
      expect(one.photos.map((p) => p.ordinal), [1, 2]);
      expect(one.photos.map((p) => p.altText), [
        'Description 1',
        'Description 2',
      ]);
      expect(
        (await s.instagramRepo.progress(one.id)).state,
        InstagramState.ready,
      );
      expect(one.revision, review.revision);
      for (final photo in one.photos) {
        final frozen = await s.instagram.fileFor(one, photo);
        expect(
          (await sha256.bind(frozen.openRead()).first).toString(),
          photo.sha256,
        );
        expect(
          p.isWithin(s.app.instagramPackageRoot.path, frozen.path),
          isTrue,
        );
      }
      expect(await s.instagramRepo.pending(), [one]);
    },
  );

  test(
    'draft changes and deleted originals do not mutate a prepared package',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Reviewed caption');
      final first = await s.instagram.prepare(review, operationId: 'first');
      final draft = (await s.app.drafts.get(review.draftId))!;
      final edited = editSharedCaption(
        draft,
        'Updated caption',
        s.app.clock.now(),
      );
      await s.app.drafts.save(edited, expectedRevision: draft.revision);
      final updated = (await s.review.review(edited)).snapshot;
      await expectLater(
        s.instagram.prepare(updated, operationId: 'first'),
        throwsStateError,
      );
      final next = await s.instagram.prepare(
        updated,
        operationId: 'deliberate-update',
      );
      expect(next.id, isNot(first.id));
      expect(next.caption, 'Updated caption');
      for (final a in review.posts[Destination.instagram]!.assets) {
        await (await s.app.media.fileFor(a.id)).delete();
      }
      expect(
        (await s.instagramRepo.get(first.id))!.caption,
        'Reviewed caption',
      );
      for (final photo in first.photos) {
        expect(
          await (await s.instagram.fileFor(first, photo)).exists(),
          isTrue,
        );
      }
      expect(await s.instagramRepo.pending(), hasLength(2));
    },
  );

  test(
    'operation identity rejects changed order descriptions hashes and revision',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Reviewed caption');
      final one = await s.instagram.prepare(review, operationId: 'same');
      final post = review.posts[Destination.instagram]!;
      final changed = [
        review.copyWith(revision: review.revision + 1),
        review.copyWith(
          posts: {
            Destination.instagram: post.copyWith(
              content: post.content.copyWith(text: 'Changed'),
            ),
          },
        ),
        review.copyWith(
          posts: {
            Destination.instagram: post.copyWith(
              content: post.content.copyWith(
                media: post.content.media.reversed.toList(),
              ),
              assets: post.assets.reversed.toList(),
            ),
          },
        ),
        review.copyWith(
          posts: {
            Destination.instagram: post.copyWith(
              content: post.content.copyWith(
                media: [
                  post.content.media.first.copyWith(altText: 'Changed'),
                  post.content.media.last,
                ],
              ),
            ),
          },
        ),
        review.copyWith(
          posts: {
            Destination.instagram: post.copyWith(
              assets: [
                post.assets.first.copyWith(sha256: '0' * 64),
                post.assets.last,
              ],
            ),
          },
        ),
      ];
      for (final different in changed) {
        expect(samePackageSource(one, different), isFalse);
        await expectLater(
          s.instagram.prepare(different, operationId: 'same'),
          throwsStateError,
        );
      }
      expect(await s.instagramRepo.pending(), [one]);
    },
  );

  test(
    'missing changed and mismatched decoded media never become ready',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Caption');
      final post = review.posts[Destination.instagram]!;
      final mismatch = review.copyWith(
        posts: {
          Destination.instagram: post.copyWith(
            assets: [post.assets.first.copyWith(width: 999), post.assets.last],
          ),
        },
      );
      await expectLater(
        s.instagram.prepare(mismatch, operationId: 'bad-metadata'),
        throwsA(
          isA<InstagramPreparationException>().having(
            (e) => e.photoOrdinal,
            'affected photo',
            1,
          ),
        ),
      );
      final file = await s.app.media.fileFor(post.assets.last.id);
      final bytes = await file.readAsBytes();
      bytes[bytes.length - 1] ^= 1;
      await file.writeAsBytes(bytes, flush: true);
      await expectLater(
        s.instagram.prepare(review, operationId: 'damaged'),
        throwsA(
          isA<InstagramPreparationException>().having(
            (e) => e.photoOrdinal,
            'affected photo',
            2,
          ),
        ),
      );
      await file.delete();
      await expectLater(
        s.instagram.prepare(review, operationId: 'missing'),
        throwsA(
          isA<InstagramPreparationException>().having(
            (e) => e.photoOrdinal,
            'affected photo',
            2,
          ),
        ),
      );
      expect(await s.instagramRepo.pending(), isEmpty);
    },
  );

  test(
    'local policy is explicit and does not borrow receiver restrictions',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('');
      final post = review.posts[Destination.instagram]!;
      expect(fixtureInstagramPolicy.validate(post), isEmpty);
      final unverified = InstagramPhotoPolicy(
        preparationVerified: false,
        maxPhotos: 2,
        mimeTypes: {'image/png'},
        evidenceVersion: 'fixture',
      );
      expect(unverified.validate(post).any((i) => i.blocking), isTrue);
      expect(
        InstagramPhotoPolicy(
          preparationVerified: true,
          maxPhotos: 1,
          mimeTypes: {'image/png'},
          evidenceVersion: 'fixture-one',
        ).validate(post).any((i) => i.blocking),
        isTrue,
      );
      final jpegOnly = InstagramPhotoPolicy(
        preparationVerified: true,
        maxPhotos: 2,
        mimeTypes: {'image/jpeg'},
        evidenceVersion: 'fixture-jpeg',
      );
      final blocked = InstagramService(
        s.instagramRepo,
        s.app.media,
        s.app.instagramPackageRoot,
        jpegOnly,
        s.app.ids,
        s.app.clock,
      );
      await expectLater(
        blocked.prepare(review, operationId: 'blocked'),
        throwsA(isA<InstagramPreparationRejected>()),
      );
      final production = InstagramPhotoPolicy.localPreparation();
      final twenty = post.copyWith(
        content: post.content.copyWith(
          media: List.generate(20, (_) => post.content.media.first),
        ),
        assets: List.generate(
          20,
          (_) => post.assets.first.copyWith(
            mimeType: 'image/jpeg',
            bytes: 9 * 1024 * 1024,
            width: 300,
            height: 900,
          ),
        ),
      );
      expect(production.validate(twenty), isEmpty);
      expect(
        production
            .validate(
              twenty.copyWith(
                content: twenty.content.copyWith(
                  media: [...twenty.content.media, twenty.content.media.first],
                ),
                assets: [...twenty.assets, twenty.assets.first],
              ),
            )
            .any((i) => i.blocking),
        isTrue,
      );
      expect(await s.instagramRepo.pending(), isEmpty);
    },
  );

  test(
    'storage full and DB commit failure retain an earlier ready package',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final review = await s.reviewTwoPhotos('Caption');
      final first = await s.instagram.prepare(review, operationId: 'kept');
      final noSpace = InstagramService(
        s.instagramRepo,
        s.app.media,
        _FullDirectory(s.app.instagramPackageRoot.path),
        s.policy,
        s.app.ids,
        s.app.clock,
      );
      await expectLater(
        noSpace.prepare(review, operationId: 'full'),
        throwsA(
          isA<InstagramPreparationException>().having(
            (e) => e.photoOrdinal,
            'affected photo',
            1,
          ),
        ),
      );
      final failedCommit = InstagramService(
        _FailingCommitRepository(s.app.database),
        s.app.media,
        s.app.instagramPackageRoot,
        s.policy,
        s.app.ids,
        s.app.clock,
      );
      await expectLater(
        failedCommit.prepare(review, operationId: 'db-failed'),
        throwsA(isA<InstagramPreparationException>()),
      );
      expect(await s.instagramRepo.findByOperation('full'), isNull);
      expect(await s.instagramRepo.findByOperation('db-failed'), isNull);
      expect(await s.instagramRepo.pending(), [first]);
      for (final photo in first.photos) {
        await s.instagram.fileFor(first, photo);
      }
    },
  );

  test('pending packages reopen after tombstone or physical draft deletion', () async {
    final s = await instagramTestServices();
    final directory = File(s.app.database.db.path).parent;
    addTearDown(() => directory.delete(recursive: true));
    final review = await s.reviewTwoPhotos('Kept independently');
    final one = await s.instagram.prepare(review, operationId: 'persist');
    await s.app.drafts.setDeleted(review.draftId, s.app.clock.now());
    expect(
      await LibraryRepository(s.app.drafts, s.instagramRepo).pendingInstagram(),
      [one],
    );
    await s.app.database.db.delete(
      'drafts',
      where: 'id = ?',
      whereArgs: [review.draftId],
    );
    // A promoted directory with no DB row models process loss before DB commit.
    final orphan = Directory(
      p.join(s.app.instagramPackageRoot.path, 'orphan-before-commit'),
    );
    await orphan.create();
    await File(p.join(orphan.path, '01.png')).writeAsString('not committed');
    await s.app.database.close();
    final reopened = await LocalDatabase.open(
      databaseFactoryFfiNoIsolate,
      s.app.database.db.path,
    );
    addTearDown(reopened.close);
    final repository = InstagramRepository(reopened);
    expect(await repository.pending(), [one]);
    expect((await repository.progress(one.id)).state, InstagramState.ready);
    expect(await repository.findByOperation('uncommitted'), isNull);
    final service = InstagramService(
      repository,
      s.app.media,
      s.app.instagramPackageRoot,
      s.policy,
      s.app.ids,
      s.app.clock,
    );
    for (final photo in one.photos) {
      expect(await (await service.fileFor(one, photo)).exists(), isTrue);
    }
  });

  test(
    'event progress is separate ordered and user confirmation is undoable',
    () async {
      final s = await instagramTestServices();
      addTearDown(s.close);
      final one = await s.instagram.prepare(
        await s.reviewTwoPhotos('Caption'),
        operationId: 'events',
      );
      final at = DateTime.utc(2026, 11, 16);
      Future<void> event(
        String id,
        InstagramEventKind kind, {
        int? ordinal,
        String? uri,
      }) => s.instagramRepo.append(
        one.id,
        InstagramEvent(
          id: id,
          kind: kind,
          at: at,
          photoOrdinal: ordinal,
          uri: uri,
          launchId: 'launch-1',
        ),
      );
      await event('copy', InstagramEventKind.captionCopied);
      await event(
        'save',
        InstagramEventKind.photoSaved,
        ordinal: 1,
        uri: 'content://fixture/1',
      );
      await event('open', InstagramEventKind.opened);
      expect(
        (await s.instagramRepo.progress(one.id)).state,
        InstagramState.ready,
      );
      await event('chooser', InstagramEventKind.chooserOpened);
      expect(
        (await s.instagramRepo.progress(one.id)).state,
        InstagramState.ready,
      );
      await event('dispatch', InstagramEventKind.targetDispatched);
      await event('return', InstagramEventKind.returnAcknowledged);
      await event('marked', InstagramEventKind.markedPosted);
      var progress = await s.instagramRepo.progress(one.id);
      expect(progress.state, InstagramState.userMarked);
      expect(progress.priorPending, InstagramState.handedOff);
      expect(progress.confirmedAt, at);
      expect(progress.savedUris, {1: 'content://fixture/1'});
      expect(progress.promptedLaunchId, 'launch-1');
      expect(await s.instagramRepo.pending(), isEmpty);
      await event('undo', InstagramEventKind.markUndone);
      progress = await s.instagramRepo.progress(one.id);
      expect(progress.state, InstagramState.handedOff);
      expect(progress.confirmedAt, isNull);
      expect(await s.instagramRepo.pending(), [one]);
      // Same event id is idempotent; another package cannot steal it.
      await event('undo', InstagramEventKind.markUndone);
      expect(await s.instagramRepo.get(one.id), one);
    },
  );

  test('append sequence preserves actions across fractional precision and clock rollback', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final one = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'fractional-events',
    );
    await s.instagramRepo.append(
      one.id,
      InstagramEvent(
        id: 'mark-later-insert',
        kind: InstagramEventKind.markedPosted,
        at: DateTime.utc(2026, 11, 16),
      ),
    );
    await s.instagramRepo.append(
      one.id,
      InstagramEvent(
        id: 'undo-microsecond',
        kind: InstagramEventKind.markUndone,
        at: DateTime.utc(2026, 11, 16, 0, 0, 0, 0, 1),
      ),
    );
    expect(
      (await s.instagramRepo.progress(one.id)).state,
      InstagramState.ready,
    );
    await s.instagramRepo.append(
      one.id,
      InstagramEvent(
        id: 'mark-again',
        kind: InstagramEventKind.markedPosted,
        at: DateTime.utc(2026, 11, 17),
      ),
    );
    await s.instagramRepo.append(
      one.id,
      InstagramEvent(
        id: 'undo-clock-back',
        kind: InstagramEventKind.markUndone,
        at: DateTime.utc(2026, 11, 15),
      ),
    );
    expect(
      (await s.instagramRepo.progress(one.id)).state,
      InstagramState.ready,
    );
  });

  test('package and progress constructors own collections including JSON and copyWith', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final one = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'own',
    );
    final photos = one.photos.toList();
    final copy = one.copyWith(photos: photos);
    photos.clear();
    expect(copy.photos, hasLength(2));
    final decoded = InstagramPackage.fromJson(
      jsonDecode(jsonEncode(one.toJson())) as Map<String, dynamic>,
    );
    expect(decoded, one);
    expect(() => decoded.photos.clear(), throwsUnsupportedError);
    final uris = {1: 'content://1'};
    final progress = InstagramProgress(
      state: InstagramState.ready,
      savedUris: uris,
    );
    uris.clear();
    expect(progress.savedUris, {1: 'content://1'});
    expect(
      InstagramProgress.fromJson(
        jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>,
      ),
      progress,
    );
  });

  test('corrupt persisted packages and events require recovery instead of disappearing', () async {
    final s = await instagramTestServices();
    addTearDown(s.close);
    final one = await s.instagram.prepare(
      await s.reviewTwoPhotos('Caption'),
      operationId: 'corrupt',
    );
    await s.app.database.db.insert('instagram_events', {
      'id': 'broken-event',
      'package_id': one.id,
      'kind': 'photoSaved',
      'at': 'invalid',
      'payload': '{}',
    });
    await expectLater(
      s.instagramRepo.pending(),
      throwsA(isA<LocalStorageException>()),
    );
    await s.app.database.db.delete('instagram_events');
    await s.app.database.db.update(
      'instagram_packages',
      {'payload': '{}'},
      where: 'id = ?',
      whereArgs: [one.id],
    );
    await expectLater(
      s.instagramRepo.get(one.id),
      throwsA(isA<LocalStorageException>()),
    );
    await expectLater(
      s.instagramRepo.pending(),
      throwsA(isA<LocalStorageException>()),
    );
  });
}

class _FailingCommitRepository extends InstagramRepository {
  _FailingCommitRepository(super.database);
  @override
  Future<void> create(InstagramPackage package) async {
    throw const LocalStorageException('Simulated package DB commit failure');
  }
}

// Inject the real OS-shaped ENOSPC boundary through the explicit directory input.
class _FullDirectory implements Directory {
  _FullDirectory(this.path);
  @override
  final String path;
  @override
  Future<Directory> create({bool recursive = false}) async =>
      throw FileSystemException(
        'No space left',
        path,
        const OSError('Disk full', 112),
      );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
