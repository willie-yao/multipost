import 'dart:async';
import 'dart:io';

import 'package:cross_posting_app/storage/local_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../support/database_fixture.dart';

void main() {
  test(
    'version one schema uses foreign keys and preserves rows across opens',
    () async {
      final fixture = await DatabaseFixture.create();
      addTearDown(fixture.dispose);
      expect(
        (await fixture.database.db.rawQuery('PRAGMA foreign_keys'))
            .single
            .values
            .single,
        1,
      );
      await fixture.database.db.insert('drafts', {
        'id': 'draft',
        'revision': 7,
        'updated_at': '2026-11-16T00:00:00Z',
        'payload': '{"preserved":true}',
      });
      await fixture.reopen();
      expect(await fixture.database.db.getVersion(), 1);
      expect((await fixture.database.db.query('drafts')).single['revision'], 7);
    },
  );

  test('unreadable database is retained instead of recreated', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'caption-corrupt-db-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/existing.db');
    await file.writeAsString('not a SQLite database');
    final expectedDiagnostics = <String>[];
    await runZoned(
      () => expectLater(
        LocalDatabase.open(databaseFactoryFfi, file.path),
        throwsA(isA<LocalStorageException>()),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.contains('file is not a database') &&
              line.contains('during open, closing...')) {
            expectedDiagnostics.add(line);
          } else {
            parent.print(zone, line);
          }
        },
      ),
    );
    expect(expectedDiagnostics, hasLength(1));
    expect(await file.readAsString(), 'not a SQLite database');
  });

  test('newer database is not downgraded or deleted', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'caption-newer-db-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/existing.db';
    final newer = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) => db.execute('CREATE TABLE keep_me(value TEXT)'),
      ),
    );
    await newer.insert('keep_me', {'value': 'original'});
    await newer.close();
    final expectedDiagnostics = <String>[];
    await runZoned(
      () => expectLater(
        LocalDatabase.open(databaseFactoryFfi, path),
        throwsA(isA<LocalStorageException>()),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (line.contains('This database needs a newer app.') &&
              line.contains('during open, closing...')) {
            expectedDiagnostics.add(line);
          } else {
            parent.print(zone, line);
          }
        },
      ),
    );
    expect(expectedDiagnostics, hasLength(1));
    final retained = await databaseFactoryFfi.openDatabase(path);
    expect(await retained.getVersion(), 2);
    expect((await retained.query('keep_me')).single['value'], 'original');
    await retained.close();
  });
  test(
    'failed schema creation rolls back without deleting existing data',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp(
        'caption-migration-db-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/existing.db';
      final previous = await databaseFactoryFfi.openDatabase(path);
      await previous.execute('CREATE TABLE drafts(kept TEXT)');
      await previous.insert('drafts', {'kept': 'original'});
      await previous.close();
      final expectedDiagnostics = <String>[];
      await runZoned(
        () => expectLater(
          LocalDatabase.open(databaseFactoryFfi, path),
          throwsA(isA<LocalStorageException>()),
        ),
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            if (line.contains('table drafts already exists') &&
                line.contains('during open, closing...')) {
              expectedDiagnostics.add(line);
            } else {
              parent.print(zone, line);
            }
          },
        ),
      );
      expect(expectedDiagnostics, hasLength(1));
      final retained = await databaseFactoryFfi.openDatabase(path);
      expect(await retained.getVersion(), 0);
      expect((await retained.query('drafts')).single['kept'], 'original');
      expect(
        await retained.rawQuery(
          "SELECT name FROM sqlite_master WHERE name = 'assets'",
        ),
        isEmpty,
      );
      await retained.close();
    },
  );
}
