import 'package:sqflite/sqflite.dart';

/// The existing database is retained on migration, IO, or parsing failures.
class LocalStorageException implements Exception {
  const LocalStorageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class LocalDatabase {
  LocalDatabase._(this.db);

  final Database db;

  static final _migrations = <Future<void> Function(DatabaseExecutor)>[
    (db) async {
      await db.execute(
        'CREATE TABLE assets(id TEXT PRIMARY KEY, payload TEXT NOT NULL)',
      );
      await db.execute('''CREATE TABLE drafts(id TEXT PRIMARY KEY,
        revision INTEGER NOT NULL, updated_at TEXT NOT NULL,
        deleted_at TEXT, payload TEXT NOT NULL)''');
      await db.execute('''CREATE TABLE picker_imports(
        id TEXT PRIMARY KEY, draft_id TEXT NOT NULL,
        draft_revision INTEGER NOT NULL, destination TEXT,
        replacement_asset_id TEXT, state TEXT NOT NULL DEFAULT 'pending',
        resolved INTEGER NOT NULL DEFAULT 0, sources TEXT)''');
      await db.execute('''CREATE UNIQUE INDEX one_unresolved_picker
        ON picker_imports(resolved) WHERE resolved = 0''');
      await db.execute('''CREATE TABLE picker_import_items(
        operation_id TEXT NOT NULL REFERENCES picker_imports(id),
        ordinal INTEGER NOT NULL, asset_id TEXT NOT NULL REFERENCES assets(id),
        PRIMARY KEY(operation_id, ordinal))''');
    },
    (db) async {
      await db.execute(
        'CREATE TABLE local_preferences(name TEXT PRIMARY KEY, value TEXT NOT NULL)',
      );
    },
  ];

  static Future<LocalDatabase> open(
    DatabaseFactory factory,
    String path,
  ) async {
    try {
      final db = await factory.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: _migrations.length,
          onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
          // sqflite runs creation/upgrades in a transaction; nesting one here
          // would deadlock. A failed migration rolls back without deleting data.
          onCreate: (db, version) => _migrate(db, 0, version),
          onUpgrade: _migrate,
          onDowngrade: (_, oldVersion, newVersion) async {
            throw const LocalStorageException(
              'This database needs a newer app. Keep the existing data.',
            );
          },
        ),
      );
      return LocalDatabase._(db);
    } catch (_) {
      throw const LocalStorageException(
        'Local storage could not open. Keep this data and try again.',
      );
    }
  }

  static Future<void> _migrate(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    for (var version = oldVersion; version < newVersion; version++) {
      await _migrations[version](db);
    }
  }

  Future<void> close() => db.close();
}
