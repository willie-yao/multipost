import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/ids.dart';
import '../../storage/local_database.dart';
import '../../storage/media_files.dart';
import '../drafts/draft.dart';

/// Results are durable media only. The caller must explicitly attach them to
/// this original draft/target after checking its revision, then acknowledge.
class PickerImportOperation {
  PickerImportOperation({
    required this.id,
    required this.draftId,
    required this.draftRevision,
    this.destination,
    this.replacementAssetId,
    required this.isComplete,
    required this.cancelled,
    required List<MediaAsset> assets,
  }) : assets = List<MediaAsset>.unmodifiable(assets);

  final String id;
  final String draftId;
  final int draftRevision;
  final Destination? destination;
  final String? replacementAssetId;
  final bool isComplete;
  final bool cancelled;
  final List<MediaAsset> assets;
}

/// One journal per user-launched picker. This service never edits a draft.
/// Bootstrap must call recoverLost before enabling another picker launch.
class PickerImports {
  PickerImports(this.files, this.ids);
  final MediaFiles files;
  final Ids ids;
  LocalDatabase get _database => files.database;

  Future<PickerImportOperation> begin({
    required String draftId,
    required int draftRevision,
    Destination? destination,
    String? replacementAssetId,
  }) => _withStorageErrors(() async {
    if (draftId.isEmpty || draftRevision < 0) {
      throw ArgumentError('An original draft and revision are required.');
    }
    final id = ids.next();
    await _database.db.transaction((txn) async {
      final pending = await txn.query('picker_imports', where: 'resolved = 0');
      if (pending.isNotEmpty) {
        throw const MediaFileException(
          'Resolve the previous picker result before choosing more media.',
        );
      }
      await txn.insert('picker_imports', {
        'id': id,
        'draft_id': draftId,
        'draft_revision': draftRevision,
        'destination': destination?.name,
        'replacement_asset_id': replacementAssetId,
      });
    });
    return _load(id);
  });

  Future<PickerImportOperation?> unresolved() => _withStorageErrors(() async {
    final rows = await _database.db.query(
      'picker_imports',
      where: 'resolved = 0',
    );
    return rows.isEmpty ? null : _load(rows.single['id'] as String);
  });

  /// Calling this again with the same ordered bytes reuses the saved assets.
  /// A changed file or selection never silently reuses a different result.
  Future<PickerImportOperation> complete(
    String operationId,
    List<XFile> selected,
  ) => _withStorageErrors(() async {
    final manifest = <Map<String, String>>[];
    try {
      for (final file in selected) {
        final digest = await sha256.bind(file.openRead()).first;
        manifest.add({'path': file.path, 'sha256': digest.toString()});
      }
    } on FileSystemException {
      throw const MediaFileException(
        'The picker source is no longer available. Keep the pending import and choose again.',
      );
    }
    await _database.db.transaction((txn) async {
      final rows = await txn.query(
        'picker_imports',
        where: 'id = ?',
        whereArgs: [operationId],
      );
      if (rows.isEmpty) {
        throw const MediaFileException(
          'This picker operation is missing. Choose again.',
        );
      }
      final row = rows.single;
      if (row['state'] == 'cancelled') {
        if (manifest.isEmpty) return;
        throw const MediaFileException(
          'This picker operation was cancelled. Choose again.',
        );
      }
      if (row['state'] == 'pending' && row['resolved'] != 0) {
        throw const MediaFileException(
          'This picker import is no longer active.',
        );
      }
      if (row['sources'] != null) {
        final previous = _sources(row);
        if (previous.length != manifest.length ||
            List.generate(
              previous.length,
              (i) => previous[i]['sha256'] == manifest[i]['sha256'],
            ).contains(false)) {
          throw const MediaFileException(
            'This selection conflicts with the saved picker result. Keep it and start a new operation.',
          );
        }
      } else {
        await txn.update(
          'picker_imports',
          {'sources': jsonEncode(manifest)},
          where: 'id = ?',
          whereArgs: [operationId],
        );
      }
    });
    return _resume(operationId, manifest);
  });

  Future<PickerImportOperation> _resume(
    String operationId,
    List<Map<String, String>> manifest,
  ) async {
    final operation = await _load(operationId);
    if (operation.isComplete || operation.cancelled) return operation;
    if (manifest.isEmpty) return cancel(operationId);
    for (var ordinal = 0; ordinal < manifest.length; ordinal++) {
      final source = manifest[ordinal];
      await files.importOperationItem(
        XFile(source['path']!),
        operationId: operationId,
        ordinal: ordinal,
        expectedSha256: source['sha256']!,
      );
    }
    final updated = await _database.db.update(
      'picker_imports',
      {'state': 'ready'},
      where: "id = ? AND state = 'pending' AND resolved = 0",
      whereArgs: [operationId],
    );
    final latest = await _load(operationId);
    if (updated == 0 && !latest.isComplete) {
      throw const MediaFileException(
        'This picker import is no longer active. Keep its saved results and choose again.',
      );
    }
    return latest;
  }

  /// Central Android bootstrap port, using image_picker's documented API.
  /// The plugin clears its cache while returning results. We persist a source
  /// manifest before importing so a later restart can resume cached sources;
  /// a crash before this manifest commits still requires honest reselection.
  Future<PickerImportOperation?> recoverLost(ImagePicker picker) =>
      _withStorageErrors(() async {
        final operation = await unresolved();
        late final LostDataResponse response;
        try {
          response = await picker.retrieveLostData();
        } on PlatformException {
          throw const MediaFileException(
            'The previous picker could not recover its result. Keep the pending import and choose again.',
          );
        }
        if (response.exception != null) {
          throw const MediaFileException(
            'The previous picker could not recover its result. Keep the pending import and choose again.',
          );
        }
        final selected =
            response.files ??
            (response.file == null ? <XFile>[] : [response.file!]);
        if (operation == null) {
          if (!response.isEmpty && selected.isNotEmpty) {
            throw const MediaFileException(
              'The recovered selection has no saved draft target. Choose it again from the intended draft.',
            );
          }
          return null;
        }
        if (selected.isNotEmpty) return complete(operation.id, selected);
        if (operation.isComplete) return operation;
        final rows = await _database.db.query(
          'picker_imports',
          where: 'id = ?',
          whereArgs: [operation.id],
        );
        if (rows.single['sources'] != null) {
          return _resume(operation.id, _sources(rows.single));
        }
        if (!response.isEmpty) return complete(operation.id, []);
        throw const MediaFileException(
          'The picker was interrupted before its result was saved. Keep the pending import, or cancel it and choose again.',
        );
      });

  /// Explicitly abandon an interrupted/failed selection. Imported successes
  /// remain durable and can still be inspected; this never deletes media.
  Future<PickerImportOperation> cancel(String operationId) =>
      _withStorageErrors(() async {
        final updated = await _database.db.update(
          'picker_imports',
          {'state': 'cancelled', 'resolved': 1},
          where: "id = ? AND state = 'pending' AND resolved = 0",
          whereArgs: [operationId],
        );
        final operation = await _load(operationId);
        if (updated == 0 && !operation.cancelled) {
          throw const MediaFileException(
            'This import is ready. Attach or discard its result explicitly.',
          );
        }
        return operation;
      });

  /// Call only after explicit attach/discard. The app owns the revision check
  /// and draft-save acknowledgment; ready results remain recoverable until then.
  Future<void> acknowledge(String operationId) => _withStorageErrors(() async {
    final updated = await _database.db.update(
      'picker_imports',
      {'resolved': 1},
      where: "id = ? AND state = 'ready'",
      whereArgs: [operationId],
    );
    if (updated == 0) {
      await _load(operationId);
      throw const MediaFileException(
        'This import is incomplete. Resolve the failed item first.',
      );
    }
  });

  Future<T> _withStorageErrors<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on DatabaseException {
      throw const LocalStorageException(
        'The picker import could not be saved or read. Keep your draft and try again.',
      );
    }
  }

  List<Map<String, String>> _sources(Map<String, Object?> row) {
    try {
      return (jsonDecode(row['sources'] as String) as List<dynamic>)
          .map((value) => Map<String, String>.from(value as Map))
          .toList();
    } catch (_) {
      throw const LocalStorageException(
        'This picker journal cannot be read. Keep the data and recover storage.',
      );
    }
  }

  Future<PickerImportOperation> _load(String id) async {
    final rows = await _database.db.query(
      'picker_imports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) {
      throw const MediaFileException('This picker operation is missing.');
    }
    final row = rows.single;
    final mapped = await _database.db.query(
      'picker_import_items',
      where: 'operation_id = ?',
      whereArgs: [id],
      orderBy: 'ordinal ASC',
    );
    final assets = <MediaAsset>[];
    for (final item in mapped) {
      final asset = await files.find(item['asset_id'] as String);
      if (asset == null) {
        throw const LocalStorageException(
          'An imported media record is missing. Keep the journal and recover storage.',
        );
      }
      assets.add(asset);
    }
    try {
      return PickerImportOperation(
        id: id,
        draftId: row['draft_id'] as String,
        draftRevision: row['draft_revision'] as int,
        destination: row['destination'] == null
            ? null
            : Destination.values.byName(row['destination'] as String),
        replacementAssetId: row['replacement_asset_id'] as String?,
        isComplete: row['state'] == 'ready',
        cancelled: row['state'] == 'cancelled',
        assets: assets,
      );
    } catch (_) {
      throw const LocalStorageException(
        'This picker journal cannot be read. Keep the data and recover storage.',
      );
    }
  }
}
