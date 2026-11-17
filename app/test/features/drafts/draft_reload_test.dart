import 'dart:async';

import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/drafts/draft_controller.dart';
import 'package:cross_posting_app/features/drafts/draft_editor.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_fixture.dart';
import '../../support/draft_fixtures.dart';

class ReadGate implements DraftRepository {
  ReadGate(this.delegate);
  final DraftRepository delegate;
  Completer<Draft?>? read;
  Object? error;
  @override
  Future<Draft?> get(String id) async {
    if (error != null) throw error!;
    return read == null ? delegate.get(id) : read!.future;
  }

  @override
  Future<List<Draft>> list() => delegate.list();
  @override
  Future<void> save(Draft draft, {required int expectedRevision}) =>
      delegate.save(draft, expectedRevision: expectedRevision);
  @override
  Future<void> setDeleted(String id, DateTime? at) =>
      delegate.setDeleted(id, at);
}

void main() {
  test('explicit reload replaces a conflicted local copy only after a successful read', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    await s.drafts.save(sampleDraft(), expectedRevision: -1);
    final c = DraftController(sampleDraft(), s.drafts, const Clock());
    addTearDown(c.dispose);
    expect(await c.flush(), isTrue);
    final competing = editSharedCaption(
      sampleDraft(),
      'Competing durable copy',
      s.clock.now(),
    );
    await s.drafts.save(competing, expectedRevision: 0);
    c.change(editSharedCaption(c.draft, 'Keep local words', s.clock.now()));
    expect(await c.flush(), isFalse);
    expect(c.lastError, isA<DraftConflict>());
    expect(
      await c.reloadAfterConflict(expectedLocalRevision: c.draft.revision),
      isTrue,
    );
    expect(c.draft, competing);
    expect(c.saveState, SaveState.saved);
    expect(c.savedRevision, competing.revision);
  });

  for (final failure in <Object?>[
    null,
    const DraftRecoveryException('draft-1'),
    const LocalStorageException('Read failed'),
  ]) {
    test(
      'failed or missing conflict reload keeps selectable local content: $failure',
      () async {
        final s = await localTestServices();
        addTearDown(s.close);
        await s.drafts.save(
          editSharedCaption(sampleDraft(), 'Competing', s.clock.now()),
          expectedRevision: -1,
        );
        final repo = ReadGate(s.drafts);
        final c = DraftController(sampleDraft(), repo, s.clock);
        addTearDown(c.dispose);
        c.change(editSharedCaption(c.draft, 'Recover me', s.clock.now()));
        expect(await c.flush(), isFalse);
        repo.error = failure;
        if (failure == null) repo.read = Completer<Draft?>()..complete(null);
        final local = c.draft;
        expect(
          await c.reloadAfterConflict(expectedLocalRevision: local.revision),
          isFalse,
        );
        expect(c.draft, local);
        expect(c.saveState, SaveState.failed);
      },
    );
  }

  test(
    'an edit during reload survives the delayed read and cannot receive Saved',
    () async {
      final s = await localTestServices();
      addTearDown(s.close);
      final competing = editSharedCaption(
        sampleDraft(),
        'Competing',
        s.clock.now(),
      );
      await s.drafts.save(competing, expectedRevision: -1);
      final repo = ReadGate(s.drafts);
      final c = DraftController(sampleDraft(), repo, s.clock);
      addTearDown(c.dispose);
      expect(await c.flush(), isFalse);
      repo.read = Completer<Draft?>();
      final reload = c.reloadAfterConflict(
        expectedLocalRevision: c.draft.revision,
      );
      await Future<void>.delayed(Duration.zero);
      c.change(editSharedCaption(c.draft, 'Newer local words', s.clock.now()));
      final flush = c.flush();
      repo.read!.complete(competing);
      expect(await reload, isFalse);
      expect(await flush, isFalse);
      expect(c.draft.shared.text, 'Newer local words');
      expect(c.saveState, isNot(SaveState.saved));
      expect(c.savedRevision, isNot(c.draft.revision));
    },
  );
  test('an edit from a reload notification invalidates both reload and joined flush acknowledgment', () async {
    final s = await localTestServices();
    addTearDown(s.close);
    final competing = editSharedCaption(
      sampleDraft(),
      'Competing',
      s.clock.now(),
    );
    await s.drafts.save(competing, expectedRevision: -1);
    final c = DraftController(sampleDraft(), s.drafts, s.clock);
    addTearDown(c.dispose);
    expect(await c.flush(), isFalse);
    var edited = false;
    c.addListener(() {
      if (!edited && c.saveState == SaveState.saved) {
        edited = true;
        c.change(editSharedCaption(c.draft, 'New after reload', s.clock.now()));
      }
    });
    final reload = c.reloadAfterConflict(
      expectedLocalRevision: c.draft.revision,
    );
    final flush = c.flush();
    expect(await reload, isFalse);
    expect(await flush, isFalse);
    expect(c.draft.shared.text, 'New after reload');
    expect(c.saveState, SaveState.saving);
    expect(c.savedRevision, competing.revision);
  });
}
