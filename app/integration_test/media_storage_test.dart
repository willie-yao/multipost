import 'dart:convert';
import 'dart:io';

import 'package:cross_posting_app/core/ids.dart';
import 'package:cross_posting_app/features/media/media_probe.dart';
import 'package:cross_posting_app/storage/local_database.dart';
import 'package:cross_posting_app/storage/media_files.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'fixtures/synthetic_video.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const reopen = bool.fromEnvironment('CAPTION_MEDIA_REOPEN');

  testWidgets(
    reopen
        ? 'owned native media survive process restart without picker sources'
        : 'native probe and private media import use synthetic files only',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final testRoot = Directory(p.join(support.path, 'l3-native-test'));
      if (!reopen && await testRoot.exists()) {
        await testRoot.delete(recursive: true);
      }
      await testRoot.create(recursive: true);
      final database = await LocalDatabase.open(
        databaseFactory,
        p.join(testRoot.path, 'test.db'),
      );
      final files = MediaFiles(
        database,
        Directory(p.join(testRoot.path, 'owned')),
        const Ids(),
      );
      final manifest = File(p.join(testRoot.path, 'ids.json'));
      try {
        if (reopen) {
          final ids = (jsonDecode(
            await manifest.readAsString(),
          ) as List<dynamic>).cast<String>();
          final assets = await Future.wait(ids.map(files.find));
          expect(assets.map((a) => a!.width), [3, 5, 320]);
          for (final asset in assets) {
            final file = await files.fileFor(asset!.id);
            expect(
              (await sha256.bind(file.openRead()).first).toString(),
              asset.sha256,
            );
          }
          expect(
            await File(p.join(testRoot.path, 'picker-first.png')).exists(),
            isFalse,
          );
          expect(
            await File(p.join(testRoot.path, 'picker-second.png')).exists(),
            isFalse,
          );
        } else {
          final video = File(p.join(testRoot.path, 'picker-video.mp4'));
          await video.writeAsBytes(
            base64Decode(syntheticVideoBase64),
            flush: true,
          );
          final metadata = await MediaProbe().inspect(video.path, 'video/mp4');
          expect((metadata.width, metadata.height), (320, 240));
          expect(metadata.durationMs, greaterThan(0));
          final firstSource = File(p.join(testRoot.path, 'picker-first.png'));
          final secondSource = File(p.join(testRoot.path, 'picker-second.png'));
          await firstSource.writeAsBytes(
            img.encodePng(img.Image(width: 3, height: 2)),
          );
          await secondSource.writeAsBytes(
            img.encodePng(img.Image(width: 5, height: 3)),
          );
          final first = await files.importFile(XFile(firstSource.path));
          final second = await files.importFile(XFile(secondSource.path));
          final clip = await files.importFile(XFile(video.path));
          expect((clip.width, clip.height), (320, 240));
          expect(clip.durationMs, greaterThan(0));
          expect(
            (await sha256.bind(video.openRead()).first).toString(),
            clip.sha256,
          );
          await expectLater(
            files.transform(clip.id, quarterTurns: 1),
            throwsA(isA<MediaFileException>()),
          );
          await manifest.writeAsString(
            jsonEncode([first.id, second.id, clip.id]),
            flush: true,
          );
          await firstSource.delete();
          await secondSource.delete();
          await video.delete();

          final outside = File(p.join(testRoot.path, 'outside.png'));
          await outside.writeAsBytes(
            img.encodePng(img.Image(width: 3, height: 2)),
          );
          final link = Link(p.join(files.root.path, 'assets', 'escape'));
          await link.create(outside.path);
          await database.db.update(
            'assets',
            {
              'payload': jsonEncode(
                first
                    .copyWith(relativePath: p.join('assets', 'escape'))
                    .toJson(),
              ),
            },
            where: 'id = ?',
            whereArgs: [first.id],
          );
          await expectLater(
            files.fileFor(first.id),
            throwsA(isA<MediaFileException>()),
          );
          await database.db.update(
            'assets',
            {'payload': jsonEncode(first.toJson())},
            where: 'id = ?',
            whereArgs: [first.id],
          );
          await link.delete();
          await outside.delete();
          await expectLater(
            MediaProbe().inspect(
              '/data/local/tmp/caption-probe.mp4',
              'video/mp4',
            ),
            throwsA(isA<MediaProbeException>()),
          );

          final corruptVideo = File(p.join(testRoot.path, 'bad.mp4'));
          await corruptVideo.writeAsBytes([
            0,
            0,
            0,
            20,
            ...ascii.encode('ftypisom'),
            0,
            0,
            0,
            0,
          ]);
          await expectLater(
            files.importFile(XFile(corruptVideo.path)),
            throwsA(isA<MediaFileException>()),
          );
          expect(await database.db.query('assets'), hasLength(3));
          await corruptVideo.delete();
        }
      } finally {
        await database.close();
        if (reopen) await testRoot.delete(recursive: true);
      }
    },
  );
}
