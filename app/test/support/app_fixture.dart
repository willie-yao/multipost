import 'dart:io';

import 'package:cross_posting_app/app/services.dart';
import 'package:cross_posting_app/core/clock.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/accounts/account_repository.dart';
import 'package:cross_posting_app/features/drafts/draft_repository.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';

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
    instagramPackageRoot: Directory('${directory.path}/instagram-packages'),
    database: database,
    media: media,
    drafts: SqliteDraftRepository(database, media: media),
    accounts: LocalAccountRepository(database),
    clock: const Clock(),
    ids: const Ids(),
    onClose: () => directory.delete(recursive: true),
  );
}

Future<void> settleEditor(WidgetTester tester) async {
  for (var step = 0; step < 40; step++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
}

Future<void> settleEditorUntil(
  WidgetTester tester,
  bool Function() ready,
) async {
  for (var step = 0; step < 300 && !ready(); step++) {
    await tester.pump(const Duration(milliseconds: 25));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  await tester.pumpAndSettle();
  expect(
    ready(),
    isTrue,
    reason: 'The editor operation did not complete within the bounded IO/frame pump.',
  );
}
