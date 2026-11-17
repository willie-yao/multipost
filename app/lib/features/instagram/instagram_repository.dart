import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/local_database.dart';
import 'instagram_package.dart';
import 'android_transfer.dart';

/// Snapshot rows are immutable. Events, never draft edits, project progress.
class InstagramRepository {
  InstagramRepository(this.database);
  final LocalDatabase database;

  Future<void> create(InstagramPackage package) async {
    _validatePackage(package);
    try {
      await database.db.insert('instagram_packages', {
        'id': package.id,
        'operation_id': package.operationId,
        'draft_id': package.draftId,
        'revision': package.revision,
        'payload': jsonEncode(package.toJson()),
      });
    } on DatabaseException {
      throw const LocalStorageException(
        'This Instagram package could not be recorded. Your previous prepared versions are kept.',
      );
    }
  }

  Future<InstagramPackage?> get(String id) => _find('id', id);
  Future<InstagramPackage?> findByOperation(String operationId) =>
      _find('operation_id', operationId);

  Future<InstagramPackage?> _find(String field, String value) async {
    final rows = await database.db.query(
      'instagram_packages',
      where: '$field = ?',
      whereArgs: [value],
    );
    return rows.isEmpty ? null : _decodePackage(rows.single);
  }

  Future<void> append(String packageId, InstagramEvent event) async {
    try {
      await database.db.transaction((tx) async {
        final rows = await tx.query(
          'instagram_packages',
          where: 'id = ?',
          whereArgs: [packageId],
        );
        if (rows.isEmpty) throw const FormatException();
        final package = _decodePackage(rows.single);
        _validateEvent(event, package);
        final existing = await tx.query(
          'instagram_events',
          where: 'id = ?',
          whereArgs: [event.id],
        );
        if (existing.isNotEmpty) {
          if (existing.single['package_id'] != packageId ||
              _decodeEvent(existing.single) != event) {
            throw const FormatException();
          }
          return;
        }
        // Check the state and append in the same transaction. Distinct event
        // IDs from simultaneous taps must not produce duplicate confirmations.
        if ({
          InstagramEventKind.markedPosted,
          InstagramEventKind.markUndone,
          InstagramEventKind.returnAcknowledged,
        }.contains(event.kind)) {
          final activity = await tx.query(
            'instagram_events',
            where: 'package_id = ?',
            whereArgs: [packageId],
            orderBy: 'rowid ASC',
          );
          final current = _project(package, activity);
          final pending =
              current.state == InstagramState.ready ||
              current.state == InstagramState.handedOff;
          if (event.kind == InstagramEventKind.markedPosted && !pending ||
              event.kind == InstagramEventKind.markUndone &&
                  current.state != InstagramState.userMarked ||
              event.kind == InstagramEventKind.returnAcknowledged &&
                  (!pending ||
                      event.launchId != current.activeLaunchId ||
                      event.launchId == current.promptedLaunchId)) {
            return;
          }
        }
        await tx.insert('instagram_events', {
          'id': event.id,
          'package_id': packageId,
          'kind': event.kind.name,
          'at': event.at.toUtc().toIso8601String(),
          'payload': jsonEncode(event.toJson()),
        });
      });
    } catch (_) {
      throw const LocalStorageException(
        'This Instagram activity could not be recorded. Keep the prepared package and try again.',
      );
    }
  }

  Future<List<InstagramEvent>> events(String packageId) => activity(packageId);

  Future<List<InstagramEvent>> activity(String packageId) async {
    final package = await get(packageId);
    if (package == null) {
      throw const LocalStorageException('Prepared package unavailable.');
    }
    final rows = await database.db.query(
      'instagram_events',
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'rowid ASC',
    );
    return [for (final row in rows) _checkedEvent(row, package)];
  }

  InstagramEvent _checkedEvent(
    Map<String, Object?> row,
    InstagramPackage package,
  ) {
    final event = _decodeEvent(row);
    _validateEvent(event, package);
    return event;
  }

  Future<InstagramProgress> progress(String packageId) async {
    final package = await get(packageId);
    if (package == null) {
      throw const LocalStorageException(
        'This prepared package is unavailable. Keep its saved data.',
      );
    }
    // Durable append order survives equal timestamps and a backward wall clock.
    // Timestamps are event/display data and never reorder recorded actions.
    final rows = await database.db.query(
      'instagram_events',
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'rowid ASC',
    );
    return _project(package, rows);
  }

  InstagramProgress _project(
    InstagramPackage package,
    List<Map<String, Object?>> rows,
  ) {
    var result = InstagramProgress(state: InstagramState.ready);
    try {
      for (final row in rows) {
        final event = _decodeEvent(row);
        _validateEvent(event, package);
        switch (event.kind) {
          case InstagramEventKind.captionCopied:
            break;
          case InstagramEventKind.photoSaved:
            result = result.copyWith(
              savedUris: {...result.savedUris, event.photoOrdinal!: event.uri!},
            );
          case InstagramEventKind.photoUnavailable:
            if (result.savedUris[event.photoOrdinal] == event.uri) {
              result = result.copyWith(
                savedUris: {...result.savedUris}..remove(event.photoOrdinal),
              );
            }
          case InstagramEventKind.opened:
          case InstagramEventKind.chooserOpened:
            result = result.copyWith(activeLaunchId: event.launchId);
          case InstagramEventKind.targetDispatched:
            result = result.copyWith(
              state: result.state == InstagramState.userMarked
                  ? result.state
                  : InstagramState.handedOff,
              activeLaunchId: event.launchId,
            );
          case InstagramEventKind.returnAcknowledged:
            result = result.copyWith(promptedLaunchId: event.launchId);
          case InstagramEventKind.markedPosted:
            if (result.state == InstagramState.ready ||
                result.state == InstagramState.handedOff) {
              result = result.copyWith(
                state: InstagramState.userMarked,
                priorPending: result.state,
                confirmedAt: event.at,
              );
            }
          case InstagramEventKind.markUndone:
            if (result.state == InstagramState.userMarked) {
              result = result.copyWith(
                state: result.priorPending ?? InstagramState.ready,
                priorPending: null,
                confirmedAt: null,
              );
            }
        }
      }
      return result;
    } catch (_) {
      throw const LocalStorageException(
        'This Instagram activity needs recovery. Its saved package has been kept.',
      );
    }
  }

  Future<List<PhotoExportJob>> exportJobs(String packageId) async {
    final package = await get(packageId);
    if (package == null) {
      throw const LocalStorageException('Package unavailable.');
    }
    final latestReceipts = <int, String>{};
    for (final event in await activity(packageId)) {
      if ({
        InstagramEventKind.photoSaved,
        InstagramEventKind.photoUnavailable,
      }.contains(event.kind)) {
        latestReceipts[event.photoOrdinal!] = event.id;
      }
    }
    final rows = await database.db.query(
      'export_jobs',
      where: 'package_id = ?',
      whereArgs: [packageId],
      orderBy: 'ordinal ASC',
    );
    return rows.map((row) {
      final id = row['id'] as String;
      final ordinal = row['ordinal'] as int;
      final uri = row['uri'] as String?;
      final completed = row['completed'];
      if (!RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(id) ||
          ordinal < 1 ||
          ordinal > package.photos.length ||
          (completed != 0 && completed != 1) ||
          (completed == 1 &&
              (uri == null || Uri.tryParse(uri)?.scheme != 'content')) ||
          (completed == 0 && uri != null)) {
        throw const LocalStorageException(
          'Photo save activity needs recovery. Its data is kept.',
        );
      }
      return PhotoExportJob(
        id: id,
        packageId: packageId,
        ordinal: ordinal,
        uri: uri,
        completed: completed == 1,
        receiptEventId: latestReceipts[ordinal],
      );
    }).toList();
  }

  Future<PhotoExportJob> ensureExportJob(
    String packageId,
    int ordinal,
    String id,
  ) async {
    final package = await get(packageId);
    if (package == null || !package.photos.any((p) => p.ordinal == ordinal)) {
      throw const LocalStorageException('Prepared photo unavailable.');
    }
    await database.db.insert('export_jobs', {
      'id': id,
      'package_id': packageId,
      'ordinal': ordinal,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return (await exportJobs(packageId))
        .singleWhere((j) => j.ordinal == ordinal);
  }

  /// Receipt and activity commit together. On failure the original job survives.
  Future<void> recordExportResult(
    PhotoExportJob job,
    String? uri,
    InstagramEvent event,
  ) async {
    await database.db.transaction((tx) async {
      final rows = await tx.query(
        'export_jobs',
        where: 'id = ? AND package_id = ? AND ordinal = ?',
        whereArgs: [job.id, job.packageId, job.ordinal],
      );
      if (rows.length != 1) {
        throw const LocalStorageException('Photo save job unavailable.');
      }
      final current = rows.single;
      if (current['uri'] != job.uri ||
          current['completed'] != (job.completed ? 1 : 0)) {
        return;
      }
      final receiptRows = await tx.query(
        'instagram_events',
        where: 'package_id = ? AND kind IN (?, ?)',
        whereArgs: [
          job.packageId,
          InstagramEventKind.photoSaved.name,
          InstagramEventKind.photoUnavailable.name,
        ],
        orderBy: 'rowid DESC',
      );
      String? latestReceiptId;
      for (final row in receiptRows) {
        final receipt = _decodeEvent(row);
        if (receipt.photoOrdinal == job.ordinal) {
          latestReceiptId = receipt.id;
          break;
        }
      }
      if (latestReceiptId != job.receiptEventId) return;
      final packageRows = await tx.query(
        'instagram_packages',
        where: 'id = ?',
        whereArgs: [job.packageId],
      );
      if (event.kind !=
              (uri == null
                  ? InstagramEventKind.photoUnavailable
                  : InstagramEventKind.photoSaved) ||
          event.uri != (uri ?? job.uri) ||
          event.photoOrdinal != job.ordinal) {
        throw const FormatException();
      }
      _validateEvent(event, _decodePackage(packageRows.single));
      await tx.insert('instagram_events', {
        'id': event.id,
        'package_id': job.packageId,
        'kind': event.kind.name,
        'at': event.at.toUtc().toIso8601String(),
        'payload': jsonEncode(event.toJson()),
      });
      await tx.update(
        'export_jobs',
        {'uri': uri, 'completed': uri == null ? 0 : 1},
        where: 'id = ?',
        whereArgs: [job.id],
      );
    });
  }

  Future<List<InstagramPackage>> pending() => _list(marked: false);
  Future<List<InstagramPackage>> marked() => _list(marked: true);

  Future<List<InstagramPackage>> _list({required bool marked}) async {
    final rows = await database.db.query(
      'instagram_packages',
      orderBy: 'rowid DESC',
    );
    final packages = <InstagramPackage>[];
    for (final row in rows) {
      final package = _decodePackage(row);
      if (((await progress(package.id)).state == InstagramState.userMarked) ==
          marked) {
        packages.add(package);
      }
    }
    return packages;
  }

  InstagramPackage _decodePackage(Map<String, Object?> row) {
    try {
      final json = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
      final package = InstagramPackage.fromJson(json);
      _validatePackage(package);
      if (!const DeepCollectionEquality().equals(
            jsonDecode(jsonEncode(package.toJson())),
            json,
          ) ||
          package.id != row['id'] ||
          package.operationId != row['operation_id'] ||
          package.draftId != row['draft_id'] ||
          package.revision != row['revision']) {
        throw const FormatException();
      }
      return package;
    } catch (_) {
      throw const LocalStorageException(
        'This Instagram package needs recovery. Its saved data has been kept.',
      );
    }
  }

  InstagramEvent _decodeEvent(Map<String, Object?> row) {
    final json = jsonDecode(row['payload'] as String) as Map<String, dynamic>;
    final event = InstagramEvent.fromJson(json);
    if (!const DeepCollectionEquality().equals(
          jsonDecode(jsonEncode(event.toJson())),
          json,
        ) ||
        event.id != row['id'] ||
        event.kind.name != row['kind'] ||
        event.at.toUtc().toIso8601String() != row['at']) {
      throw const FormatException();
    }
    return event;
  }

  void _validatePackage(InstagramPackage package) {
    if (!RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(package.id) ||
        package.operationId.trim().isEmpty ||
        package.draftId.isEmpty ||
        package.revision < 0 ||
        package.photos.isEmpty) {
      throw const FormatException();
    }
    for (var index = 0; index < package.photos.length; index++) {
      final photo = package.photos[index];
      final number = (index + 1).toString().padLeft(2, '0');
      if (photo.ordinal != index + 1 ||
          photo.assetId.isEmpty ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(photo.sha256) ||
          ![
            '${package.id}/$number.png',
            '${package.id}/$number.jpg',
          ].contains(photo.relativePath)) {
        throw const FormatException();
      }
    }
  }

  void _validateEvent(InstagramEvent event, InstagramPackage package) {
    if (event.id.isEmpty) throw const FormatException();
    if (event.kind == InstagramEventKind.targetDispatched &&
        event.targetPackage != 'com.instagram.android') {
      throw const FormatException();
    }
    if (event.kind != InstagramEventKind.targetDispatched &&
        event.targetPackage != null) {
      throw const FormatException();
    }
    if ({
          InstagramEventKind.photoSaved,
          InstagramEventKind.photoUnavailable,
        }.contains(event.kind) &&
        (event.photoOrdinal == null ||
            event.photoOrdinal! < 1 ||
            event.photoOrdinal! > package.photos.length ||
            event.uri == null ||
            !event.uri!.startsWith('content://'))) {
      throw const FormatException();
    }
    if ({
          InstagramEventKind.opened,
          InstagramEventKind.chooserOpened,
          InstagramEventKind.targetDispatched,
          InstagramEventKind.returnAcknowledged,
        }.contains(event.kind) &&
        (event.launchId == null || event.launchId!.isEmpty)) {
      throw const FormatException();
    }
  }
}
