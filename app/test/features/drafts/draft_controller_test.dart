import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/database_fixture.dart';
import '../../support/draft_fixtures.dart';

class FixedClock extends Clock {
  const FixedClock();
  @override
  DateTime now() => DateTime.utc(2026, 11, 17);
}

/// The controlled completion models slow disk without changing controller code.
class DelayedDraftRepository implements DraftRepository {
  final Map<String, Draft> rows = {};
  final List<Draft> writes = [];
  final List<int> expectedRevisions = [];
  final List<Completer<void>> completions = [];

  @override
  Future<Draft?> get(String id) async => rows[id];
  @override
  Future<List<Draft>> list() async => rows.values.toList();
  @override
  Future<void> setDeleted(String id, DateTime? at) async {
    rows[id] = rows[id]!.copyWith(deletedAt: at);
  }

  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    writes.add(draft);
    expectedRevisions.add(expectedRevision);
    final completion = Completer<void>();
    completions.add(completion);
    await completion.future;
    if ((rows[draft.id]?.revision ?? -1) != expectedRevision) {
      throw DraftConflict(draft.id);
    }
    rows[draft.id] = draft;
  }
}

Future<void> settleLane() => Future<void>.delayed(Duration.zero);

void main() {
  testWidgets('debounces quick edits and saves only the latest snapshot', (
    tester,
  ) async {
    final repo = DelayedDraftRepository();
    final controller = DraftController(sampleDraft(), repo, const FixedClock());
    addTearDown(controller.dispose);
    for (final text in ['a', 'ab', 'abc']) {
      controller.change(
        editSharedCaption(controller.draft, text, const FixedClock().now()),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(controller.saveState, SaveState.saving);
    expect(controller.savedRevision, -1);
    expect(repo.writes, isEmpty);
    await tester.pump(const Duration(milliseconds: 250));
    expect(repo.writes.single.shared.text, 'abc');
    expect(repo.expectedRevisions, [-1]);
    repo.completions.single.complete();
    await tester.pump();
    expect(controller.savedRevision, 3);
    expect(controller.saveState, SaveState.saved);
    expect((await repo.get('draft-1'))!.shared.text, 'abc');
  });

  test('stale acknowledgement never labels a newer edit Saved', () async {
    final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
    final controller = DraftController(sampleDraft(), repo, const FixedClock());
    addTearDown(controller.dispose);
    controller.change(
      editSharedCaption(controller.draft, 'First', const FixedClock().now()),
    );
    final flushed = controller.flush();
    await settleLane();
    controller.change(
      editSharedCaption(controller.draft, 'Second', const FixedClock().now()),
    );
    final concurrentFlush = controller.flush();
    expect(repo.writes, hasLength(1));
    repo.completions[0].complete();
    await settleLane();
    expect(controller.savedRevision, 1);
    expect(controller.saveState, isNot(SaveState.saved));
    expect(repo.writes, hasLength(2));
    expect(repo.expectedRevisions, [0, 1]);
    repo.completions[1].complete();
    expect(await flushed, isTrue);
    expect(await concurrentFlush, isTrue);
    expect(controller.savedRevision, 2);
    expect(controller.saveState, SaveState.saved);
    expect((await repo.get('draft-1'))!.shared.text, 'Second');
  });

  test(
    'failed flush returns false with unsaved edits; retry saves current text',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      controller.change(
        editSharedCaption(controller.draft, 'First', const FixedClock().now()),
      );
      final flushed = controller.flush();
      await settleLane();
      controller.change(
        editSharedCaption(
          controller.draft,
          'Keep this',
          const FixedClock().now(),
        ),
      );
      repo.completions[0].completeError(const FileSystemException('disk full'));
      expect(await flushed, isFalse);
      expect(controller.saveState, SaveState.failed);
      expect(controller.lastError, isA<FileSystemException>());
      expect(controller.savedRevision, 0);
      expect(controller.draft.shared.text, 'Keep this');
      expect(
        (await repo.get('draft-1'))!.shared.text,
        sampleDraft().shared.text,
      );
      expect(repo.writes, hasLength(1));
      final retry = controller.retrySave();
      await settleLane();
      expect(controller.saveState, SaveState.saving);
      expect(repo.writes.last.revision, 2);
      expect(repo.expectedRevisions, [0, 0]);
      repo.completions[1].complete();
      expect(await retry, isTrue);
      expect(controller.lastError, isNull);
      expect(controller.saveState, SaveState.saved);
      expect((await repo.get('draft-1'))!.shared.text, 'Keep this');
    },
  );

  test(
    'a second write failure propagates through the original flush',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      controller.change(
        editSharedCaption(controller.draft, 'First', const FixedClock().now()),
      );
      final flushed = controller.flush();
      await settleLane();
      controller.change(
        editSharedCaption(controller.draft, 'Second', const FixedClock().now()),
      );
      repo.completions[0].complete();
      await settleLane();
      repo.completions[1].completeError(const FileSystemException('disk full'));
      expect(await flushed, isFalse);
      expect(controller.savedRevision, 1);
      expect(controller.saveState, SaveState.failed);
      expect((await repo.get('draft-1'))!.shared.text, 'First');
    },
  );

  test(
    'conflict preserves local text and retry never rebases onto remote text',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      expect(await controller.flush(), isTrue);
      final remote = editSharedCaption(
        sampleDraft(),
        'Other editor',
        DateTime.utc(2026),
      );
      repo.rows['draft-1'] = remote;
      controller.change(
        editSharedCaption(
          controller.draft,
          'Local text',
          const FixedClock().now(),
        ),
      );
      var flushed = controller.flush();
      await settleLane();
      repo.completions[0].complete();
      expect(await flushed, isFalse);
      expect(controller.lastError, isA<DraftConflict>());
      expect(controller.draft.shared.text, 'Local text');
      flushed = controller.retrySave();
      await settleLane();
      repo.completions[1].complete();
      expect(await flushed, isFalse);
      expect(await repo.get('draft-1'), remote);
      expect(repo.expectedRevisions, [0, 0]);
    },
  );

  test(
    'restored snapshot is checked without writing; a new draft inserts',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final restored = DraftController(sampleDraft(), repo, const FixedClock());
      addTearDown(restored.dispose);
      expect(await restored.flush(), isTrue);
      expect(restored.savedRevision, 0);
      expect(restored.saveState, SaveState.saved);
      expect(repo.writes, isEmpty);
      final fresh = DraftController(
        sampleDraft().copyWith(id: 'new'),
        repo,
        const FixedClock(),
      );
      addTearDown(fresh.dispose);
      final flushed = fresh.flush();
      await settleLane();
      expect(fresh.saveState, SaveState.saving);
      expect(fresh.savedRevision, -1);
      repo.completions.single.complete();
      expect(await flushed, isTrue);
      expect((await repo.get('new'))!.revision, 0);
    },
  );

  test(
    'stale initial snapshot does not overwrite the durable record',
    () async {
      final repo = DelayedDraftRepository()
        ..rows['draft-1'] = editSharedCaption(
          sampleDraft(),
          'Durable',
          DateTime.utc(2026),
        );
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      expect(await controller.flush(), isFalse);
      expect(controller.saveState, SaveState.failed);
      expect(controller.lastError, isA<DraftConflict>());
      expect(controller.draft.shared.text, sampleDraft().shared.text);
      expect(repo.writes, isEmpty);
    },
  );

  test(
    'a flush started at completion still waits for the current edit',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      await controller.flush();
      var queued = false;
      var secondFinished = false;
      Future<bool>? secondFlush;
      controller.addListener(() {
        if (controller.saveState == SaveState.saved && !queued) {
          queued = true;
          scheduleMicrotask(() {
            controller.change(
              editSharedCaption(
                controller.draft,
                'Latest',
                const FixedClock().now(),
              ),
            );
            secondFlush = controller.flush().then((result) {
              secondFinished = true;
              return result;
            });
          });
        }
      });
      controller.change(
        editSharedCaption(controller.draft, 'First', const FixedClock().now()),
      );
      final firstFlush = controller.flush();
      await settleLane();
      repo.completions[0].complete();
      await settleLane();
      expect(secondFinished, isFalse);
      expect(repo.writes, hasLength(2));
      repo.completions[1].complete();
      expect(await firstFlush, isTrue);
      expect(await secondFlush, isTrue);
      expect((await repo.get('draft-1'))!.shared.text, 'Latest');
    },
  );

  test(
    'same-revision divergent initial text fails without replacing either copy',
    () async {
      final repo = DelayedDraftRepository()..rows['draft-1'] = sampleDraft();
      final local = sampleDraft().copyWith(
        shared: PostContent(text: 'Unconfirmed local'),
      );
      final controller = DraftController(local, repo, const FixedClock());
      addTearDown(controller.dispose);
      expect(await controller.flush(), isFalse);
      expect(controller.lastError, isA<DraftConflict>());
      expect(controller.draft.shared.text, 'Unconfirmed local');
      expect(
        (await repo.get('draft-1'))!.shared.text,
        sampleDraft().shared.text,
      );
      expect(repo.writes, isEmpty);
    },
  );
  test('rejects different ids and non-advancing revisions', () async {
    final controller = DraftController(
      sampleDraft(),
      DelayedDraftRepository(),
      const FixedClock(),
    );
    addTearDown(controller.dispose);
    expect(
      () => controller.change(sampleDraft().copyWith(id: 'other', revision: 1)),
      throwsArgumentError,
    );
    expect(
      () => controller.change(
        sampleDraft().copyWith(shared: PostContent(text: 'Unversioned')),
      ),
      throwsArgumentError,
    );
    expect(controller.draft, sampleDraft());
  });

  test(
    'SQLite storage-full and replacement failure expose recoverable failure',
    () async {
      final fixture = await DatabaseFixture.create();
      addTearDown(fixture.dispose);
      final repo = SqliteDraftRepository(
        fixture.database,
        media: fixture.files,
      );
      await repo.save(sampleDraft(), expectedRevision: -1);
      final controller = DraftController(
        sampleDraft(),
        repo,
        const FixedClock(),
      );
      addTearDown(controller.dispose);
      controller.change(
        editSharedCaption(
          controller.draft,
          'Keep this text',
          const FixedClock().now(),
        ),
      );
      await fixture.database.db.execute(
        '''CREATE TRIGGER simulate_full
      BEFORE UPDATE ON drafts BEGIN SELECT RAISE(ABORT, 'database or disk is full'); END''',
      );
      expect(await controller.flush(), isFalse);
      expect(controller.saveState, SaveState.failed);
      expect(controller.lastError, isA<LocalStorageException>());
      expect((await repo.get('draft-1'))!.revision, 0);
      await fixture.database.db.execute('DROP TRIGGER simulate_full');
      expect(await controller.retrySave(), isTrue);
      final saved = controller.draft;
      controller.change(
        editSharedMedia(controller.draft, [
          const Attachment(assetId: 'failed-replacement'),
        ], const FixedClock().now()),
      );
      expect(await controller.flush(), isFalse);
      expect(controller.lastError, isA<MediaFileException>());
      expect(
        controller.draft.shared.media.single.assetId,
        'failed-replacement',
      );
      expect(await repo.get('draft-1'), saved);
      controller.change(
        editSharedMedia(controller.draft, [], const FixedClock().now()),
      );
      expect(await controller.retrySave(), isTrue);
      expect((await repo.get('draft-1'))!.shared.text, 'Keep this text');
    },
  );
}
