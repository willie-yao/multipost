import 'dart:io';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<AppServices> localTestServices() async {
  sqfliteFfiInit();
  final directory = await Directory.systemTemp.createTemp('caption-app-');
  final database = await LocalDatabase.open(
    databaseFactoryFfiNoIsolate,
    '${directory.path}/caption.db',
  );
  final media = MediaFiles(
    database,
    Directory('${directory.path}/media'),
    const Ids(),
  );
  return AppServices(
    database: database,
    media: media,
    drafts: SqliteDraftRepository(database, media: media),
    accounts: LocalAccountRepository(database),
    clock: const Clock(),
    ids: const Ids(),
    onClose: () => directory.delete(recursive: true),
  );
}
