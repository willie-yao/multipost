import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../storage/local_database.dart';
import '../../storage/media_files.dart';
import 'draft.dart';

abstract interface class DraftRepository {
  /// Includes tombstones so recovery and Undo can address a hidden draft.
  Future<Draft?> get(String id);
  Future<List<Draft>> list();
  Future<void> save(Draft draft, {required int expectedRevision});
  Future<void> setDeleted(String id, DateTime? at);
}

class DraftConflict implements Exception {
  const DraftConflict(this.draftId);
  final String draftId;

  @override
  String toString() =>
      'This draft changed in storage. Keep your unsaved text before choosing to reload.';
}

/// The row is retained. Consumers must show recovery instead of an empty draft.
class DraftRecoveryException implements Exception {
  const DraftRecoveryException(this.draftId);
  final String draftId;

  @override
  String toString() =>
      'This draft cannot be read. Keep its saved data and recover it before editing.';
}

class SqliteDraftRepository implements DraftRepository {
  SqliteDraftRepository(this.database, {this.media});

  final LocalDatabase database;
  final MediaFiles? media;

  @override
  Future<Draft?> get(String id) async {
    final rows = await database.db.query(
      'drafts',
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty ? null : _decode(rows.single);
  }

  /// Corrupt rows raise a recovery notice; they are never silently omitted.
  @override
  Future<List<Draft>> list() async {
    final rows = await database.db.query(
      'drafts',
      orderBy: 'updated_at DESC, id',
    );
    return rows.map(_decode).where((draft) => draft.deletedAt == null).toList();
  }

  @override
  Future<void> save(Draft draft, {required int expectedRevision}) async {
    if (expectedRevision < -1 ||
        draft.revision < 0 ||
        draft.revision <= expectedRevision) {
      throw ArgumentError(
        'A saved draft revision must advance its expected revision.',
      );
    }
    final assets = {
      ...draft.shared.media.map((attachment) => attachment.assetId),
      for (final version in draft.versions.values)
        ...?version.ownMedia?.map((attachment) => attachment.assetId),
    };
    if (assets.isNotEmpty && media == null) {
      throw const MediaFileException(
        'Media storage is unavailable. Keep this screen open and try saving again.',
      );
    }
    // Validate every stored reference, including currently deselected versions,
    // before acquiring a write transaction. Never infer the private media root.
    for (final asset in assets) {
      await media!.fileFor(asset);
    }
    try {
      await database.db.transaction((tx) async {
        final row = _encode(draft);
        if (expectedRevision == -1) {
          final existing = await tx.query(
            'drafts',
            columns: ['id'],
            where: 'id = ?',
            whereArgs: [draft.id],
          );
          if (existing.isNotEmpty) throw DraftConflict(draft.id);
          await tx.insert('drafts', row);
        } else {
          final existing = await tx.query(
            'drafts',
            where: 'id = ? AND revision = ?',
            whereArgs: [draft.id, expectedRevision],
          );
          if (existing.isEmpty) throw DraftConflict(draft.id);
          // A cached editor must not overwrite evidence needed for recovery.
          _decode(existing.single);
          final changed = await tx.update(
            'drafts',
            row,
            where: 'id = ? AND revision = ?',
            whereArgs: [draft.id, expectedRevision],
          );
          if (changed != 1) throw DraftConflict(draft.id);
        }
      });
    } on DatabaseException {
      throw const LocalStorageException(
        'The draft could not be saved. Keep this screen open and try again.',
      );
    }
  }

  /// Deletion/Undo advances revision, invalidating pending editor writes.
  /// Existing assets are retained even if their private files need recovery.
  @override
  Future<void> setDeleted(String id, DateTime? at) async {
    try {
      await database.db.transaction((tx) async {
        final rows = await tx.query('drafts', where: 'id = ?', whereArgs: [id]);
        if (rows.isEmpty) throw DraftConflict(id);
        final current = _decode(rows.single);
        final next = current.copyWith(
          deletedAt: at,
          revision: current.revision + 1,
          updatedAt: at ?? DateTime.now().toUtc(),
        );
        final changed = await tx.update(
          'drafts',
          _encode(next),
          where: 'id = ? AND revision = ?',
          whereArgs: [id, current.revision],
        );
        if (changed != 1) throw DraftConflict(id);
      });
    } on DatabaseException {
      throw const LocalStorageException(
        'The draft change could not be saved. Try again.',
      );
    }
  }

  Map<String, Object?> _encode(Draft draft) => {
    'id': draft.id,
    'revision': draft.revision,
    'updated_at': draft.updatedAt.toIso8601String(),
    'deleted_at': draft.deletedAt?.toIso8601String(),
    'payload': jsonEncode({'schemaVersion': 1, 'draft': draft.toJson()}),
  };

  Draft _decode(Map<String, Object?> row) {
    final id = row['id'] as String;
    try {
      final payload =
          jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      if (payload['schemaVersion'] != 1) throw const FormatException();
      final content = payload['draft'] as Map<String, dynamic>;
      final draft = Draft.fromJson(content);
      // Generated model decoders allow defaults and numeric coercion. Durable
      // records must be complete and lossless instead of quietly losing edits.
      if (!_sameJson(draft.toJson(), content) ||
          draft.revision < 0 ||
          draft.sharedTextRevision < 0 ||
          draft.sharedMediaRevision < 0 ||
          draft.id != id ||
          draft.revision != row['revision'] ||
          draft.updatedAt.toIso8601String() != row['updated_at'] ||
          draft.deletedAt?.toIso8601String() != row['deleted_at']) {
        throw const FormatException();
      }
      return draft;
    } catch (_) {
      throw DraftRecoveryException(id);
    }
  }
}

bool _sameJson(Object? left, Object? right) {
  if (left is Map && right is Map) {
    return left.length == right.length &&
        left.keys.every(
          (key) => right.containsKey(key) && _sameJson(left[key], right[key]),
        );
  }
  if (left is List && right is List) {
    return left.length == right.length &&
        List.generate(
          left.length,
          (index) => index,
        ).every((index) => _sameJson(left[index], right[index]));
  }
  if (left is int && right is! int) return false;
  return left == right;
}
