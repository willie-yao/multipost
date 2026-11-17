import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/media/picker_imports.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import '../support/database_fixture.dart';

class RecoveryPicker extends ImagePicker {
  RecoveryPicker(this.response);
  final LostDataResponse response;
  @override
  Future<LostDataResponse> retrieveLostData() async => response;
}

class ThrowingRecoveryPicker extends ImagePicker {
  @override
  Future<LostDataResponse> retrieveLostData() async =>
      throw PlatformException(code: 'storage_unavailable');
}

class PausedXFile extends XFile {
  PausedXFile(super.path, this.started, this.resume);
  final Completer<void> started;
  final Completer<void> resume;

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    started.complete();
    await resume.future;
    yield* super.openRead(start, end);
  }
}

class PausedImportFiles extends MediaFiles {
  PausedImportFiles(
    super.database,
    super.root,
    super.ids, {
    required this.afterCommit,
  });
  final bool afterCommit;
  final started = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<MediaAsset> importOperationItem(
    XFile file, {
    required String operationId,
    required int ordinal,
    required String expectedSha256,
  }) async {
    final asset = await super.importOperationItem(
      ordinal == 1 && !afterCommit
          ? PausedXFile(file.path, started, resume)
          : file,
      operationId: operationId,
      ordinal: ordinal,
      expectedSha256: expectedSha256,
    );
    if (ordinal == 1 && afterCommit) {
      started.complete();
      await resume.future;
    }
    return asset;
  }
}

void main() {
  late DatabaseFixture fixture;
  PickerImports imports() => PickerImports(fixture.files, const Ids());
  setUp(() async => fixture = await DatabaseFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'cancelled picker creates no media and permits another launch',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 3,
      );
      final result = await imports().complete(operation.id, []);
      expect(result.cancelled, isTrue);
      expect(result.assets, isEmpty);
      expect(await fixture.database.db.query('assets'), isEmpty);
      expect(await imports().unresolved(), isNull);
      await imports().begin(draftId: 'draft', draftRevision: 3);
    },
  );

  test('one unresolved launch retains exact target through restart', () async {
    final operation = await imports().begin(
      draftId: 'draft',
      draftRevision: 8,
      destination: Destination.bluesky,
      replacementAssetId: 'old-asset',
    );
    await fixture.reopen();
    final recovered = (await imports().unresolved())!;
    expect(
      (
        recovered.id,
        recovered.draftId,
        recovered.draftRevision,
        recovered.destination,
        recovered.replacementAssetId,
      ),
      (operation.id, 'draft', 8, Destination.bluesky, 'old-asset'),
    );
    await expectLater(
      imports().begin(draftId: 'newer', draftRevision: 9),
      throwsA(isA<MediaFileException>()),
    );
  });

  test(
    'completed repeated callback reuses ordered assets by operation ID',
    () async {
      final selected = [
        await fixture.photo('a.png', width: 3),
        await fixture.photo('b.png', width: 7),
      ];
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 1,
      );
      final first = await imports().complete(operation.id, selected);
      await fixture.reopen();
      final repeated = await imports().complete(operation.id, selected);
      expect(repeated.assets.map((a) => a.id), first.assets.map((a) => a.id));
      expect(repeated.assets.map((a) => a.width), [3, 7]);
      expect(await fixture.database.db.query('assets'), hasLength(2));
      expect((await imports().unresolved())!.isComplete, isTrue);
      await imports().acknowledge(operation.id);
      expect(await imports().unresolved(), isNull);
    },
  );

  test(
    'same operation cannot silently reuse assets for conflicting content',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 0,
      );
      await imports().complete(operation.id, [
        await fixture.photo('a.png', width: 3),
      ]);
      await expectLater(
        imports().complete(operation.id, [
          await fixture.photo('b.png', width: 4),
        ]),
        throwsA(isA<MediaFileException>()),
      );
      expect(await fixture.database.db.query('assets'), hasLength(1));
      expect((await imports().unresolved())!.assets.single.width, 3);
    },
  );

  test(
    'failure after first item journals it and does not claim complete',
    () async {
      final good = await fixture.photo('a.png');
      final bad = File('${fixture.directory.path}/bad.png');
      await bad.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 0,
      );
      await expectLater(
        imports().complete(operation.id, [good, XFile(bad.path)]),
        throwsA(isA<MediaFileException>()),
      );
      await fixture.reopen();
      final partial = (await imports().unresolved())!;
      expect(partial.isComplete, isFalse);
      expect(partial.assets, hasLength(1));
      final originalId = partial.assets.single.id;
      await expectLater(
        imports().complete(operation.id, [good, XFile(bad.path)]),
        throwsA(isA<MediaFileException>()),
      );
      expect((await imports().unresolved())!.assets.single.id, originalId);
      expect(await fixture.database.db.query('assets'), hasLength(1));
      await expectLater(
        imports().acknowledge(operation.id),
        throwsA(isA<MediaFileException>()),
      );
    },
  );

  test(
    'asset and ordinal mapping roll back together on journal failure',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 1,
      );
      await fixture.database.db.execute(
        "CREATE TRIGGER reject_mapping BEFORE INSERT ON picker_import_items BEGIN SELECT RAISE(ABORT, 'synthetic disk failure'); END",
      );
      await expectLater(
        imports().complete(operation.id, [await fixture.photo('a.png')]),
        throwsA(isA<LocalStorageException>()),
      );
      expect(await fixture.database.db.query('assets'), isEmpty);
      expect(await fixture.database.db.query('picker_import_items'), isEmpty);
      expect(
        await Directory('${fixture.directory.path}/owned/assets').list().length,
        1,
      );
      await fixture.database.db.execute('DROP TRIGGER reject_mapping');
      final retried = await imports().recoverLost(
        RecoveryPicker(LostDataResponse.empty()),
      );
      expect(retried!.assets, hasLength(1));
      expect(retried.isComplete, isTrue);
      expect(await fixture.database.db.query('assets'), hasLength(1));
    },
  );

  test('cancelling failed batch preserves its imported successes', () async {
    final good = await fixture.photo('a.png');
    final bad = File('${fixture.directory.path}/bad.png');
    await bad.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    final operation = await imports().begin(draftId: 'draft', draftRevision: 1);
    await expectLater(
      imports().complete(operation.id, [good, XFile(bad.path)]),
      throwsA(isA<MediaFileException>()),
    );
    final cancelled = await imports().cancel(operation.id);
    expect(cancelled.assets, hasLength(1));
    expect(cancelled.cancelled, isTrue);
    expect(
      await (await fixture.files.fileFor(cancelled.assets.single.id)).exists(),
      isTrue,
    );
    expect(await imports().unresolved(), isNull);
  });

  test(
    'lost-picker result becomes private copies bound to original target',
    () async {
      final selected = [
        await fixture.photo('a.png'),
        await fixture.photo('b.png', width: 5),
      ];
      final operation = await imports().begin(
        draftId: 'original',
        draftRevision: 4,
      );
      await fixture.reopen();
      final recovered = (await imports().recoverLost(
        RecoveryPicker(
          LostDataResponse(
            files: selected,
            file: selected.last,
            type: RetrieveType.image,
          ),
        ),
      ))!;
      expect(recovered.id, operation.id);
      expect((recovered.draftId, recovered.draftRevision), ('original', 4));
      expect(recovered.isComplete, isTrue);
      for (final source in selected) {
        await File(source.path).delete();
      }
      await fixture.reopen();
      final repeated = (await imports().recoverLost(
        RecoveryPicker(LostDataResponse.empty()),
      ))!;
      expect(
        repeated.assets.map((a) => a.id),
        recovered.assets.map((a) => a.id),
      );
      for (final asset in repeated.assets) {
        expect(await (await fixture.files.fileFor(asset.id)).exists(), isTrue);
      }
      expect(await fixture.database.db.query('drafts'), isEmpty);
    },
  );

  test('lost-picker error preserves pending operation for recovery', () async {
    final operation = await imports().begin(draftId: 'draft', draftRevision: 4);
    await expectLater(
      imports().recoverLost(
        RecoveryPicker(
          LostDataResponse(
            exception: PlatformException(code: 'photo_access_denied'),
          ),
        ),
      ),
      throwsA(isA<MediaFileException>()),
    );
    expect((await imports().unresolved())!.id, operation.id);
    expect(await fixture.database.db.query('assets'), isEmpty);
  });

  test(
    'empty recovery does not pretend an unfinished launch was cancelled',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 2,
      );
      await expectLater(
        imports().recoverLost(RecoveryPicker(LostDataResponse.empty())),
        throwsA(isA<MediaFileException>()),
      );
      expect((await imports().unresolved())!.id, operation.id);
    },
  );
  test(
    'thrown picker platform error becomes recoverable without losing operation',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 4,
      );
      await expectLater(
        imports().recoverLost(ThrowingRecoveryPicker()),
        throwsA(isA<MediaFileException>()),
      );
      expect((await imports().unresolved())!.id, operation.id);
    },
  );
  for (final afterCommit in [false, true]) {
    test(
      'cancellation survives suspended ${afterCommit ? 'ready transition' : 'file copy'}',
      () async {
        final pausedFiles = PausedImportFiles(
          fixture.database,
          Directory('${fixture.directory.path}/owned'),
          const Ids(),
          afterCommit: afterCommit,
        );
        final service = PickerImports(pausedFiles, const Ids());
        final operation = await service.begin(
          draftId: 'original',
          draftRevision: 4,
        );
        final selected = [
          await fixture.photo('first.png'),
          await fixture.photo('second.png', width: 5),
        ];
        final completion = service.complete(operation.id, selected);
        // Attach the error listener before releasing the deterministic suspension.
        final rejected = expectLater(
          completion,
          throwsA(isA<MediaFileException>()),
        );
        await pausedFiles.started.future;
        try {
          final cancelled = await imports().cancel(operation.id);
          expect(cancelled.assets, hasLength(afterCommit ? 2 : 1));
          final next = await imports().begin(draftId: 'next', draftRevision: 1);
          pausedFiles.resume.complete();
          await rejected;
          final row = (await fixture.database.db.query(
            'picker_imports',
            where: 'id = ?',
            whereArgs: [operation.id],
          )).single;
          expect((row['state'], row['resolved']), ('cancelled', 1));
          expect(
            await fixture.database.db.query(
              'picker_import_items',
              where: 'operation_id = ?',
              whereArgs: [operation.id],
            ),
            hasLength(afterCommit ? 2 : 1),
          );
          expect(
            await fixture.database.db.query('assets'),
            hasLength(afterCommit ? 2 : 1),
          );
          expect((await imports().unresolved())!.id, next.id);
        } finally {
          if (!pausedFiles.resume.isCompleted) pausedFiles.resume.complete();
          await completion.then<void>((_) {}, onError: (Object _) {});
        }
      },
    );
  }

  test(
    'failed manifest write is recoverable and preserves the pending operation',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 1,
      );
      final selected = [await fixture.photo('a.png')];
      await fixture.database.db.execute(
        "CREATE TRIGGER reject_manifest BEFORE UPDATE OF sources ON picker_imports BEGIN SELECT RAISE(ABORT, 'synthetic manifest failure'); END",
      );
      await expectLater(
        imports().complete(operation.id, selected),
        throwsA(isA<LocalStorageException>()),
      );
      final row = (await fixture.database.db.query(
        'picker_imports',
        where: 'id = ?',
        whereArgs: [operation.id],
      )).single;
      expect(
        (row['state'], row['sources'], row['resolved']),
        ('pending', null, 0),
      );
      expect(await fixture.database.db.query('assets'), isEmpty);
      await fixture.database.db.execute('DROP TRIGGER reject_manifest');
      expect(
        (await imports().complete(operation.id, selected)).isComplete,
        isTrue,
      );
    },
  );

  test('failed ready write preserves imported assets for recovery without source files', () async {
    final operation = await imports().begin(draftId: 'draft', draftRevision: 1);
    final source = await fixture.photo('a.png');
    await fixture.database.db.execute(
      "CREATE TRIGGER reject_ready BEFORE UPDATE OF state ON picker_imports WHEN NEW.state = 'ready' BEGIN SELECT RAISE(ABORT, 'synthetic ready failure'); END",
    );
    await expectLater(
      imports().complete(operation.id, [source]),
      throwsA(isA<LocalStorageException>()),
    );
    final pending = (await imports().unresolved())!;
    expect(pending.isComplete, isFalse);
    expect(pending.assets, hasLength(1));
    final id = pending.assets.single.id;
    await File(source.path).delete();
    await fixture.database.db.execute('DROP TRIGGER reject_ready');
    final recovered = (await imports().recoverLost(
      RecoveryPicker(LostDataResponse.empty()),
    ))!;
    expect(recovered.isComplete, isTrue);
    expect(recovered.assets.single.id, id);
    expect(await fixture.database.db.query('assets'), hasLength(1));
  });
  test(
    'failed journal creation is recoverable without creating an operation',
    () async {
      await fixture.database.db.execute(
        "CREATE TRIGGER reject_begin BEFORE INSERT ON picker_imports BEGIN SELECT RAISE(ABORT, 'synthetic begin failure'); END",
      );
      await expectLater(
        imports().begin(draftId: 'draft', draftRevision: 1),
        throwsA(isA<LocalStorageException>()),
      );
      expect(await fixture.database.db.query('picker_imports'), isEmpty);
      await fixture.database.db.execute('DROP TRIGGER reject_begin');
      expect(
        (await imports().begin(draftId: 'draft', draftRevision: 1)).draftId,
        'draft',
      );
    },
  );

  test('failed journal cancellation retains the pending target', () async {
    final operation = await imports().begin(draftId: 'draft', draftRevision: 1);
    await fixture.database.db.execute(
      "CREATE TRIGGER reject_cancel BEFORE UPDATE OF state ON picker_imports WHEN NEW.state = 'cancelled' BEGIN SELECT RAISE(ABORT, 'synthetic cancel failure'); END",
    );
    await expectLater(
      imports().cancel(operation.id),
      throwsA(isA<LocalStorageException>()),
    );
    final pending = (await imports().unresolved())!;
    expect(
      (pending.id, pending.isComplete, pending.cancelled),
      (operation.id, false, false),
    );
    await fixture.database.db.execute('DROP TRIGGER reject_cancel');
    expect((await imports().cancel(operation.id)).cancelled, isTrue);
  });

  test('failed journal acknowledgment retains the ready result', () async {
    final operation = await imports().begin(draftId: 'draft', draftRevision: 1);
    final ready = await imports().complete(operation.id, [
      await fixture.photo('a.png'),
    ]);
    await fixture.database.db.execute(
      "CREATE TRIGGER reject_ack BEFORE UPDATE OF resolved ON picker_imports WHEN NEW.resolved = 1 BEGIN SELECT RAISE(ABORT, 'synthetic acknowledgment failure'); END",
    );
    await expectLater(
      imports().acknowledge(operation.id),
      throwsA(isA<LocalStorageException>()),
    );
    final pending = (await imports().unresolved())!;
    expect(pending.isComplete, isTrue);
    expect(pending.assets.single.id, ready.assets.single.id);
    await fixture.database.db.execute('DROP TRIGGER reject_ack');
    await imports().acknowledge(operation.id);
    expect(await imports().unresolved(), isNull);
  });

  test(
    'failed journal read is recoverable and retains the original data',
    () async {
      final operation = await imports().begin(
        draftId: 'draft',
        draftRevision: 1,
      );
      await fixture.database.db.execute(
        'ALTER TABLE picker_imports RENAME TO inaccessible_picker_imports',
      );
      try {
        await expectLater(
          imports().unresolved(),
          throwsA(isA<LocalStorageException>()),
        );
      } finally {
        await fixture.database.db.execute(
          'ALTER TABLE inaccessible_picker_imports RENAME TO picker_imports',
        );
      }
      expect((await imports().unresolved())!.id, operation.id);
    },
  );
}
