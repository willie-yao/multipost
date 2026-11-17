import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/ids.dart';
import '../features/drafts/draft.dart';
import '../features/media/media_probe.dart';
import 'local_database.dart';

class MediaFileException implements Exception {
  const MediaFileException(this.message);
  final String message;
  @override
  String toString() => message;
}

class MediaFiles {
  MediaFiles(this.database, this.root, this.ids);

  final LocalDatabase database;
  final Directory root;
  final Ids ids;

  Future<MediaAsset> importFile(XFile file) => _import(file);

  /// Feature-owned picker journal boundary. Call through PickerImports.
  /// The asset row and operation/ordinal mapping commit together.
  Future<MediaAsset> importOperationItem(
    XFile file, {
    required String operationId,
    required int ordinal,
    required String expectedSha256,
  }) async {
    final operations = await database.db.query(
      'picker_imports',
      where: 'id = ?',
      whereArgs: [operationId],
    );
    _requireActiveImport(operations);
    final mapped = await database.db.query(
      'picker_import_items',
      where: 'operation_id = ? AND ordinal = ?',
      whereArgs: [operationId, ordinal],
    );
    if (mapped.isNotEmpty) {
      final existing = await find(mapped.single['asset_id'] as String);
      if (existing == null || existing.sha256 != expectedSha256) {
        throw const MediaFileException(
          'The picker result conflicts with this import. Keep the existing result and choose again.',
        );
      }
      await fileFor(existing.id);
      return existing;
    }
    return _import(
      file,
      operationId: operationId,
      ordinal: ordinal,
      expectedSha256: expectedSha256,
    );
  }

  Future<MediaAsset> _import(
    XFile file, {
    String? operationId,
    int? ordinal,
    String? expectedSha256,
  }) async {
    File? partial;
    var ownsPartial = false;
    try {
      final privateRoot = await _prepareRoot();
      final id = ids.next();
      partial = await _safeFile(
        privateRoot,
        p.join('imports', '$id.part'),
        exists: false,
      );
      await partial.create(exclusive: true);
      ownsPartial = true;
      final sink = partial.openWrite();
      try {
        await sink.addStream(file.openRead());
        await sink.flush();
      } finally {
        await sink.close();
      }
      return await _promote(
        partial,
        privateRoot,
        id,
        operationId: operationId,
        ordinal: ordinal,
        expectedSha256: expectedSha256,
      );
    } on MediaProbeException catch (error) {
      throw MediaFileException(error.message);
    } on FileSystemException {
      throw const MediaFileException(
        'The media could not be copied. Keep your draft and try again or replace it.',
      );
    } finally {
      if (ownsPartial && partial != null && await partial.exists()) {
        await partial.delete();
      }
    }
  }

  /// Crop uses display-oriented original pixels, before clockwise rotation.
  /// Call only after the user confirms an original/expected-result preview.
  /// The new PNG omits EXIF and other carried metadata; the source is unchanged.
  Future<MediaAsset> transform(
    String assetId, {
    required int quarterTurns,
    Rect? cropPixels,
  }) async {
    final original = await find(assetId);
    if (original == null) {
      throw const MediaFileException('This media item is missing.');
    }
    if (!original.mimeType.startsWith('image/')) {
      throw const MediaFileException(
        'Video crop, rotation, trimming and transcoding are unsupported. Keep the original or replace it.',
      );
    }
    final source = await fileFor(assetId);
    final sourcePath = source.path;
    final mimeType = original.mimeType;
    File? partial;
    var ownsPartial = false;
    try {
      final privateRoot = await _prepareRoot();
      final id = ids.next();
      partial = await _safeFile(
        privateRoot,
        p.join('imports', '$id.part'),
        exists: false,
      );
      await partial.create(exclusive: true);
      ownsPartial = true;
      final outputPath = partial.path;
      await Isolate.run(
        () => _writeDerivative(
          sourcePath,
          mimeType,
          outputPath,
          quarterTurns,
          cropPixels,
        ),
      );
      return await _promote(
        partial,
        privateRoot,
        id,
        originalAssetId: original.originalAssetId ?? original.id,
      );
    } on MediaProbeException catch (error) {
      throw MediaFileException(error.message);
    } on FileSystemException {
      throw const MediaFileException(
        'The edited photo could not be saved. Your original is unchanged.',
      );
    } finally {
      if (ownsPartial && partial != null && await partial.exists()) {
        await partial.delete();
      }
    }
  }

  Future<MediaAsset> _promote(
    File partial,
    String privateRoot,
    String id, {
    String? originalAssetId,
    String? operationId,
    int? ordinal,
    String? expectedSha256,
  }) async {
    final input = await partial.open();
    late final String mimeType;
    try {
      mimeType = detectMediaType(await input.read(64));
    } finally {
      await input.close();
    }
    final metadata = await MediaProbe().inspect(partial.path, mimeType);
    final digest = (await sha256.bind(partial.openRead()).first).toString();
    if (expectedSha256 != null && digest != expectedSha256) {
      throw const MediaFileException(
        'This picker source changed during import. Choose it again.',
      );
    }
    final relativePath = p.join('assets', id);
    final destination = await _safeFile(
      privateRoot,
      relativePath,
      exists: false,
    );
    if (await destination.exists()) {
      throw const MediaFileException('The media ID already exists. Try again.');
    }
    final bytes = await partial.length();
    await partial.rename(destination.path);
    final asset = MediaAsset(
      id: id,
      relativePath: relativePath,
      mimeType: mimeType,
      bytes: bytes,
      sha256: digest,
      width: metadata.width,
      height: metadata.height,
      durationMs: metadata.durationMs,
      originalAssetId: originalAssetId,
    );
    try {
      return await database.db.transaction((txn) async {
        if (operationId != null) {
          final operations = await txn.query(
            'picker_imports',
            where: 'id = ?',
            whereArgs: [operationId],
          );
          _requireActiveImport(operations);
          final mapped = await txn.query(
            'picker_import_items',
            where: 'operation_id = ? AND ordinal = ?',
            whereArgs: [operationId, ordinal],
          );
          if (mapped.isNotEmpty) {
            final rows = await txn.query(
              'assets',
              where: 'id = ?',
              whereArgs: [mapped.single['asset_id']],
            );
            final existing = _assetFromRow(
              rows.single,
              mapped.single['asset_id'] as String,
            );
            if (existing.sha256 != digest) {
              throw const MediaFileException(
                'Conflicting picker import. Keep the existing result and choose again.',
              );
            }
            return existing;
          }
          if (operations.single['state'] != 'pending') {
            throw const MediaFileException(
              'This picker import is already ready. Keep its saved results and choose again.',
            );
          }
        }
        await txn.insert('assets', {
          'id': id,
          'payload': jsonEncode(asset.toJson()),
        });
        if (operationId != null) {
          await txn.insert('picker_import_items', {
            'operation_id': operationId,
            'ordinal': ordinal,
            'asset_id': id,
          });
        }
        return asset;
      });
    } on DatabaseException {
      // A promoted orphan is kept. Cleanup requires checking all persisted
      // references and is deliberately a separate, explicit operation.
      throw const LocalStorageException(
        'Media storage could not commit. Your existing draft is safe; try again.',
      );
    }
  }

  void _requireActiveImport(List<Map<String, Object?>> operations) {
    if (operations.isEmpty ||
        !{'pending', 'ready'}.contains(operations.single['state']) ||
        operations.single['resolved'] != 0) {
      throw const MediaFileException(
        'This picker import is no longer active. Keep its saved results and choose again.',
      );
    }
  }

  Future<MediaAsset?> find(String assetId) async {
    final rows = await database.db.query(
      'assets',
      where: 'id = ?',
      whereArgs: [assetId],
    );
    return rows.isEmpty ? null : _assetFromRow(rows.single, assetId);
  }

  MediaAsset _assetFromRow(Map<String, Object?> row, String id) {
    try {
      final asset = MediaAsset.fromJson(
        jsonDecode(row['payload'] as String) as Map<String, dynamic>,
      );
      if (asset.id != id ||
          asset.bytes <= 0 ||
          asset.width <= 0 ||
          asset.height <= 0 ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(asset.sha256)) {
        throw const FormatException();
      }
      return asset;
    } catch (_) {
      throw const LocalStorageException(
        'This media record cannot be read. Keep your draft and recover or replace the item.',
      );
    }
  }

  Future<File> fileFor(String assetId) async {
    final asset = await find(assetId);
    if (asset == null) {
      throw const MediaFileException(
        'This media item is missing. Replace or remove it.',
      );
    }
    try {
      final privateRoot = await _prepareRoot();
      final file = await _safeFile(
        privateRoot,
        asset.relativePath,
        exists: true,
      );
      if (await file.length() != asset.bytes) {
        throw const MediaFileException(
          'The private copy is damaged. Replace or remove this item.',
        );
      }
      return file;
    } on FileSystemException {
      throw const MediaFileException(
        'The private copy cannot be opened. Replace or remove this item.',
      );
    }
  }

  Future<String> _prepareRoot() async {
    await root.create(recursive: true);
    final privateRoot = await root.resolveSymbolicLinks();
    for (final name in ['imports', 'assets']) {
      final directory = Directory(p.join(privateRoot, name));
      await directory.create();
      final resolved = await directory.resolveSymbolicLinks();
      if (!p.isWithin(privateRoot, resolved)) {
        throw const MediaFileException(
          'The private media folder is unsafe. Keep your data and recover storage.',
        );
      }
    }
    return privateRoot;
  }

  Future<File> _safeFile(
    String privateRoot,
    String relative, {
    required bool exists,
  }) async {
    final path = p.normalize(p.join(privateRoot, relative));
    if (p.isAbsolute(relative) ||
        !p.isWithin(privateRoot, path) ||
        p.split(relative).contains('..')) {
      throw const MediaFileException(
        'This media path is outside private storage. Replace or remove it.',
      );
    }
    final parent = await Directory(p.dirname(path)).resolveSymbolicLinks();
    if (!p.isWithin(privateRoot, parent)) {
      throw const MediaFileException(
        'This media path is outside private storage. Replace or remove it.',
      );
    }
    final file = File(path);
    if (await file.exists()) {
      if (!p.isWithin(privateRoot, await file.resolveSymbolicLinks())) {
        throw const MediaFileException(
          'This media path is outside private storage. Replace or remove it.',
        );
      }
    } else if (exists) {
      throw const MediaFileException(
        'The private copy is missing. Replace or remove this item.',
      );
    }
    return file;
  }
}

void _writeDerivative(
  String source,
  String mimeType,
  String destination,
  int quarterTurns,
  Rect? crop,
) {
  var image = decodePhoto(source, mimeType);
  if (crop != null) {
    final edges = [crop.left, crop.top, crop.right, crop.bottom];
    if (edges.any((v) => !v.isFinite || v != v.roundToDouble()) ||
        crop.left < 0 ||
        crop.top < 0 ||
        crop.width <= 0 ||
        crop.height <= 0 ||
        crop.right > image.width ||
        crop.bottom > image.height) {
      throw const MediaProbeException(
        'Choose a whole-pixel crop within the original photo.',
      );
    }
    image = img.copyCrop(
      image,
      x: crop.left.toInt(),
      y: crop.top.toInt(),
      width: crop.width.toInt(),
      height: crop.height.toInt(),
    );
  }
  final turns = quarterTurns % 4;
  if (turns != 0) image = img.copyRotate(image, angle: turns * 90);
  image.exif = img.ExifData();
  image.textData = null;
  File(destination).writeAsBytesSync(img.encodePng(image), flush: true);
}
