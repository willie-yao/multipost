import 'dart:io';

import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseFixture {
  DatabaseFixture._(this.directory, this.database);
  final Directory directory;
  LocalDatabase database;
  String get path => '${directory.path}/test.db';
  MediaFiles get files =>
      MediaFiles(database, Directory('${directory.path}/owned'), const Ids());

  static Future<DatabaseFixture> create() async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp('caption-storage-');
    final database = await LocalDatabase.open(
      databaseFactoryFfi,
      '${directory.path}/test.db',
    );
    return DatabaseFixture._(directory, database);
  }

  Future<XFile> photo(String name, {int width = 8, int height = 8}) async {
    final source = File('${directory.path}/$name');
    await source.writeAsBytes(
      img.encodePng(img.Image(width: width, height: height)),
    );
    return XFile(source.path);
  }

  Future<void> reopen() async {
    await database.close();
    database = await LocalDatabase.open(databaseFactoryFfi, path);
  }

  Future<void> dispose() async {
    await database.close();
    await directory.delete(recursive: true);
  }
}
