import 'dart:convert';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixture.dart';
import '../../support/draft_fixtures.dart';

void main() {
  late DatabaseFixture fixture;
  late SqliteDraftRepository repo;
  setUp(() async {
    fixture = await DatabaseFixture.create();
    repo = SqliteDraftRepository(fixture.database, media: fixture.files);
  });
  tearDown(() => fixture.dispose());

  test('reopen restores overrides and the last stage', () async {
    var draft = editOwnCaption(
      sampleDraft(),
      Destination.bluesky,
      'Own caption',
      DateTime.utc(2026),
    );
    draft = setStage(draft, ComposeStage.review, DateTime.utc(2026, 1, 2));
    await repo.save(draft, expectedRevision: -1);
    await fixture.reopen();
    expect(await SqliteDraftRepository(fixture.database).get(draft.id), draft);
  });

  test(
    'insert only and stale update conflicts preserve durable text',
    () async {
      final original = sampleDraft();
      await repo.save(original, expectedRevision: -1);
      await expectLater(
        repo.save(original, expectedRevision: -1),
        throwsA(
          isA<DraftConflict>().having((e) => e.draftId, 'id', original.id),
        ),
      );
      final saved = editSharedCaption(original, 'Saved', DateTime.utc(2026));
      await repo.save(saved, expectedRevision: 0);
      await expectLater(
        repo.save(
          editSharedCaption(original, 'Stale', DateTime.utc(2026)),
          expectedRevision: 0,
        ),
        throwsA(isA<DraftConflict>()),
      );
      expect(await repo.get(original.id), saved);
      expect((await repo.list()).single.shared.text, 'Saved');
    },
  );

  test(
    'revision must advance so an old acknowledgement cannot overwrite',
    () async {
      final original = sampleDraft();
      await repo.save(original, expectedRevision: -1);
      await expectLater(
        repo.save(
          original.copyWith(shared: PostContent(text: 'Lost')),
          expectedRevision: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(await repo.get(original.id), original);
    },
  );

  test(
    'tombstone and Undo persist matching indexes and preserve media',
    () async {
      final asset = await fixture.files.importFile(
        await fixture.photo('owned.png'),
      );
      final original = sampleDraft().copyWith(
        shared: PostContent(media: [Attachment(assetId: asset.id)]),
      );
      await repo.save(original, expectedRevision: -1);
      final deletedAt = DateTime.utc(2026, 12);
      await repo.setDeleted(original.id, deletedAt);
      expect(await repo.list(), isEmpty);
      final deleted = (await repo.get(original.id))!;
      expect(deleted.deletedAt, deletedAt);
      expect(deleted.revision, 1);
      await expectLater(
        repo.save(original.copyWith(revision: 1), expectedRevision: 0),
        throwsA(isA<DraftConflict>()),
      );
      await fixture.reopen();
      repo = SqliteDraftRepository(fixture.database, media: fixture.files);
      await repo.setDeleted(original.id, null);
      final restored = (await repo.list()).single;
      expect(restored.deletedAt, isNull);
      expect(restored.revision, 2);
      expect(restored.shared.media.single.assetId, asset.id);
      expect(await fixture.files.find(asset.id), asset);
      expect(await (await fixture.files.fileFor(asset.id)).exists(), isTrue);
      final row = (await fixture.database.db.query('drafts')).single;
      expect(row['revision'], 2);
      expect(row['deleted_at'], isNull);
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      expect(payload['schemaVersion'], 1);
      expect((payload['draft'] as Map)['revision'], 2);
      await expectLater(
        repo.setDeleted('absent', null),
        throwsA(isA<DraftConflict>()),
      );
    },
  );

  test(
    'corrupt, incomplete and future payloads retain the original row',
    () async {
      await repo.save(sampleDraft(), expectedRevision: -1);
      final validRow = (await fixture.database.db.query('drafts')).single;
      for (final payload in [
        '{bad json',
        '{}',
        jsonEncode({'schemaVersion': 999, 'draft': sampleDraft().toJson()}),
        jsonEncode({
          'schemaVersion': 1,
          'draft': {
            'id': 'draft-1',
            'updatedAt': sampleDraft().updatedAt.toIso8601String(),
          },
        }),
      ]) {
        await fixture.database.db.update('drafts', {'payload': payload});
        await expectLater(
          repo.get('draft-1'),
          throwsA(
            isA<DraftRecoveryException>().having(
              (e) => e.draftId,
              'id',
              'draft-1',
            ),
          ),
        );
        await expectLater(repo.list(), throwsA(isA<DraftRecoveryException>()));
        expect(
          (await fixture.database.db.query('drafts')).single['payload'],
          payload,
        );
      }
      await fixture.database.db.update('drafts', validRow);
      for (final field in ['revision', 'updated_at', 'deleted_at']) {
        await fixture.database.db.update('drafts', {
          field: field == 'revision' ? 8 : '2027-01-01T00:00:00.000Z',
        });
        await expectLater(
          repo.get('draft-1'),
          throwsA(isA<DraftRecoveryException>()),
        );
        await fixture.database.db.update('drafts', validRow);
      }
    },
  );

  test(
    'missing validator blocks media but supports a text-only constructor',
    () async {
      final textRepo = SqliteDraftRepository(fixture.database);
      await textRepo.save(sampleDraft(), expectedRevision: -1);
      final mediaDraft = editSharedMedia(sampleDraft(), [
        const Attachment(assetId: 'missing'),
      ], DateTime.utc(2026));
      await expectLater(
        textRepo.save(mediaDraft, expectedRevision: 0),
        throwsA(isA<MediaFileException>()),
      );
      expect((await textRepo.get('draft-1'))!.revision, 0);
    },
  );

  test(
    'validates deselected own-media and shared media before replacing draft',
    () async {
      final asset = await fixture.files.importFile(
        await fixture.photo('good.png'),
      );
      final draft = sampleDraft().copyWith(
        selected: {Destination.x},
        shared: PostContent(media: [Attachment(assetId: asset.id)]),
      );
      await repo.save(draft, expectedRevision: -1);
      final badOverride = editOwnMedia(draft, Destination.instagram, [
        const Attachment(assetId: 'missing'),
      ], DateTime.utc(2026));
      await expectLater(
        repo.save(badOverride, expectedRevision: 0),
        throwsA(isA<MediaFileException>()),
      );
      await (await fixture.files.fileFor(asset.id)).delete();
      await expectLater(
        repo.save(draft.copyWith(revision: 1), expectedRevision: 0),
        throwsA(isA<MediaFileException>()),
      );
      expect(await repo.get(draft.id), draft);
    },
  );

  test(
    'invalid media metadata preserves the previous complete draft',
    () async {
      final original = sampleDraft();
      await repo.save(original, expectedRevision: -1);
      await fixture.database.db.insert('assets', {
        'id': 'broken',
        'payload': '{}',
      });
      await expectLater(
        repo.save(
          editSharedMedia(original, [
            const Attachment(assetId: 'broken'),
          ], DateTime.utc(2026)),
          expectedRevision: 0,
        ),
        throwsA(isA<LocalStorageException>()),
      );
      expect(await repo.get(original.id), original);
    },
  );

  test(
    'saving never overwrites a corrupt existing row at the expected revision',
    () async {
      await repo.save(sampleDraft(), expectedRevision: -1);
      await fixture.database.db.update('drafts', {'payload': '{unreadable'});
      final retained = (await fixture.database.db.query('drafts')).single;
      await expectLater(
        repo.save(
          editSharedCaption(sampleDraft(), 'Unsaved', DateTime.utc(2026)),
          expectedRevision: 0,
        ),
        throwsA(isA<DraftRecoveryException>()),
      );
      expect((await fixture.database.db.query('drafts')).single, retained);
    },
  );
  test('storage-full failure rolls back JSON and index together', () async {
    final original = sampleDraft();
    await repo.save(original, expectedRevision: -1);
    final before = (await fixture.database.db.query('drafts')).single;
    await fixture.database.db.execute(
      '''CREATE TRIGGER simulate_full
      BEFORE UPDATE ON drafts BEGIN SELECT RAISE(ABORT, 'database or disk is full'); END''',
    );
    await expectLater(
      repo.save(
        editSharedCaption(original, 'Unsaved', DateTime.utc(2026)),
        expectedRevision: 0,
      ),
      throwsA(isA<LocalStorageException>()),
    );
    expect((await fixture.database.db.query('drafts')).single, before);
    expect(await repo.get(original.id), original);
  });
}
