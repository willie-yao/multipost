import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/media/media_probe.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../support/database_fixture.dart';

class CollisionIds extends Ids {
  const CollisionIds();
  @override
  String next() => 'collision';
}

void main() {
  late DatabaseFixture fixture;
  setUp(() async => fixture = await DatabaseFixture.create());
  tearDown(() => fixture.dispose());

  test(
    'import owns its bytes after picker source disappears and DB reopens',
    () async {
      final source = await fixture.photo('source.png');
      final originalHash = sha256
          .convert(await File(source.path).readAsBytes())
          .toString();
      final asset = await fixture.files.importFile(source);
      await File(source.path).delete();
      await fixture.reopen();
      expect(
        await (await fixture.files.fileFor(asset.id)).length(),
        asset.bytes,
      );
      expect(asset.sha256, originalHash);
      expect((await fixture.files.find(asset.id))?.width, 8);
    },
  );

  test('MIME comes from bytes despite filename and picker hint', () async {
    final source = await fixture.photo('pretend.mp4');
    final asset = await fixture.files.importFile(
      XFile(source.path, mimeType: 'video/mp4'),
    );
    expect(asset.mimeType, 'image/png');
    expect(asset.durationMs, isNull);
  });

  test(
    'failed stream removes only its own partial and leaves draft untouched',
    () async {
      final imports = Directory('${fixture.directory.path}/owned/imports');
      await imports.create(recursive: true);
      final other = File('${imports.path}/unrelated.part');
      await other.writeAsString('keep');
      await fixture.database.db.insert('drafts', {
        'id': 'draft',
        'revision': 7,
        'updated_at': '2026-11-16T00:00:00Z',
        'payload': '{"keep":true}',
      });
      await expectLater(
        fixture.files.importFile(XFile('${fixture.directory.path}/missing')),
        throwsA(isA<MediaFileException>()),
      );
      expect(await other.readAsString(), 'keep');
      expect(await imports.list().length, 1);
      expect(await fixture.database.db.query('assets'), isEmpty);
      expect((await fixture.database.db.query('drafts')).single['revision'], 7);
    },
  );

  test('corrupt photo has no asset or guessed dimensions', () async {
    final file = File('${fixture.directory.path}/bad.png');
    await file.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    await expectLater(
      fixture.files.importFile(XFile(file.path)),
      throwsA(isA<MediaFileException>()),
    );
    expect(await fixture.database.db.query('assets'), isEmpty);
    expect(
      await Directory('${fixture.directory.path}/owned/imports').list().length,
      0,
    );
  });

  test(
    'declared oversized photo is rejected before pixel allocation',
    () async {
      final bytes = img.encodePng(img.Image(width: 1, height: 1));
      // PNG IHDR width=100000 and height=100000, far over the decode budget.
      for (final offset in [16, 20]) {
        bytes[offset] = 0;
        bytes[offset + 1] = 1;
        bytes[offset + 2] = 0x86;
        bytes[offset + 3] = 0xa0;
      }
      final source = File('${fixture.directory.path}/large.png');
      await source.writeAsBytes(bytes);
      await expectLater(
        fixture.files.importFile(XFile(source.path)),
        throwsA(isA<MediaFileException>()),
      );
      expect(await fixture.database.db.query('assets'), isEmpty);
    },
  );

  test('encoded photo budget is checked before decoding', () async {
    final source = File('${fixture.directory.path}/large.png');
    await source.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    final handle = await source.open(mode: FileMode.append);
    await handle.truncate(maxPhotoEncodedBytes + 1);
    await handle.close();
    await expectLater(
      fixture.files.importFile(XFile(source.path)),
      throwsA(isA<MediaFileException>()),
    );
  });

  test(
    'missing owned file is recoverable while its record is retained',
    () async {
      final asset = await fixture.files.importFile(
        await fixture.photo('a.png'),
      );
      await (await fixture.files.fileFor(asset.id)).delete();
      await expectLater(
        fixture.files.fileFor(asset.id),
        throwsA(isA<MediaFileException>()),
      );
      expect(await fixture.files.find(asset.id), asset);
    },
  );

  test(
    'stored absolute and traversal paths cannot open external files',
    () async {
      final asset = await fixture.files.importFile(
        await fixture.photo('source.png'),
      );
      for (final relative in [
        '../source.png',
        '${fixture.directory.path}/source.png',
      ]) {
        await fixture.database.db.update(
          'assets',
          {
            'payload': jsonEncode(
              asset.copyWith(relativePath: relative).toJson(),
            ),
          },
          where: 'id = ?',
          whereArgs: [asset.id],
        );
        await expectLater(
          fixture.files.fileFor(asset.id),
          throwsA(isA<MediaFileException>()),
        );
      }
    },
  );

  test('malformed asset payload is retained and reported', () async {
    await fixture.database.db.insert('assets', {
      'id': 'bad',
      'payload': '{bad',
    });
    await expectLater(
      fixture.files.find('bad'),
      throwsA(isA<LocalStorageException>()),
    );
    expect(
      (await fixture.database.db.query('assets')).single['payload'],
      '{bad',
    );
    expect(await fixture.files.find('absent'), isNull);
  });

  test(
    'crop then clockwise rotation creates derivative with original hash intact',
    () async {
      final image = img.Image(width: 4, height: 2);
      for (var y = 0; y < 2; y++) {
        for (var x = 0; x < 4; x++) {
          image.setPixelRgba(x, y, x * 40, y * 100, 0, 255);
        }
      }
      final source = File('${fixture.directory.path}/grid.png');
      await source.writeAsBytes(img.encodePng(image));
      final original = await fixture.files.importFile(XFile(source.path));
      final edited = await fixture.files.transform(
        original.id,
        quarterTurns: 1,
        cropPixels: const Rect.fromLTWH(1, 0, 3, 2),
      );
      expect(edited.id, isNot(original.id));
      expect(edited.originalAssetId, original.id);
      expect((edited.width, edited.height), (2, 3));
      final decoded = img.decodePng(
        await (await fixture.files.fileFor(edited.id)).readAsBytes(),
      )!;
      final pixel = decoded.getPixel(0, 0);
      expect((pixel.r.toInt(), pixel.g.toInt()), (40, 100));
      expect(
        sha256
            .convert(
              await (await fixture.files.fileFor(original.id)).readAsBytes(),
            )
            .toString(),
        original.sha256,
      );
    },
  );

  test(
    'invalid and fractional crops fail without creating derivatives',
    () async {
      final original = await fixture.files.importFile(
        await fixture.photo('original.png'),
      );
      for (final crop in [
        const Rect.fromLTWH(-1, 0, 4, 4),
        const Rect.fromLTWH(0, 0, 0, 1),
        const Rect.fromLTWH(0.5, 0, 2, 2),
        const Rect.fromLTWH(0, 0, 100, 1),
      ]) {
        await expectLater(
          fixture.files.transform(
            original.id,
            quarterTurns: 0,
            cropPixels: crop,
          ),
          throwsA(isA<MediaFileException>()),
        );
      }
      expect(await fixture.database.db.query('assets'), hasLength(1));
    },
  );

  test(
    'photo derivatives strip location EXIF and preserve display orientation',
    () async {
      final image = img.Image(width: 3, height: 2);
      image.exif.imageIfd.orientation = 6;
      image.exif.gpsIfd.setGpsLocation(latitude: 37.5, longitude: -122.5);
      final source = File('${fixture.directory.path}/gps.jpg');
      await source.writeAsBytes(img.encodeJpg(image));
      expect(
        img.decodeJpg(await source.readAsBytes())!.exif.gpsIfd.hasGPSLatitude,
        isTrue,
      );
      final original = await fixture.files.importFile(XFile(source.path));
      expect((original.width, original.height), (2, 3));
      final edited = await fixture.files.transform(
        original.id,
        quarterTurns: 0,
      );
      final result = img.decodePng(
        await (await fixture.files.fileFor(edited.id)).readAsBytes(),
      )!;
      expect((result.width, result.height), (2, 3));
      expect(result.exif.gpsIfd.hasGPSLatitude, isFalse);
      expect(
        img.decodeJpg(await source.readAsBytes())!.exif.gpsIfd.hasGPSLatitude,
        isTrue,
      );
    },
  );

  test(
    'two imported files remain distinct ordered references after reopen',
    () async {
      final first = await fixture.files.importFile(
        await fixture.photo('first.png', width: 3),
      );
      final second = await fixture.files.importFile(
        await fixture.photo('second.png', width: 7),
      );
      final content = PostContent(
        media: [
          Attachment(assetId: second.id),
          Attachment(assetId: first.id),
        ],
      );
      final restored = PostContent.fromJson(
        jsonDecode(jsonEncode(content.toJson())) as Map<String, dynamic>,
      );
      await fixture.reopen();
      expect(restored.media.map((a) => a.assetId), [second.id, first.id]);
      expect(
        (await fixture.files.find(restored.media.first.assetId))!.width,
        7,
      );
      expect((await fixture.files.find(restored.media.last.assetId))!.width, 3);
    },
  );
  test(
    'UUID collision import preserves a partial it failed to create',
    () async {
      final directory = Directory('${fixture.directory.path}/owned/imports');
      await directory.create(recursive: true);
      final previous = File('${directory.path}/collision.part');
      await previous.writeAsString('another import owns this partial');
      final files = MediaFiles(
        fixture.database,
        Directory('${fixture.directory.path}/owned'),
        const CollisionIds(),
      );
      await expectLater(
        files.importFile(await fixture.photo('new.png')),
        throwsA(isA<MediaFileException>()),
      );
      expect(await previous.readAsString(), 'another import owns this partial');
    },
  );

  test(
    'UUID collision derivative preserves a partial it failed to create',
    () async {
      final original = await fixture.files.importFile(
        await fixture.photo('original.png'),
      );
      final previous = File(
        '${fixture.directory.path}/owned/imports/collision.part',
      );
      await previous.writeAsString('another import owns this partial');
      final files = MediaFiles(
        fixture.database,
        Directory('${fixture.directory.path}/owned'),
        const CollisionIds(),
      );
      await expectLater(
        files.transform(original.id, quarterTurns: 1),
        throwsA(isA<MediaFileException>()),
      );
      expect(await previous.readAsString(), 'another import owns this partial');
    },
  );
}
