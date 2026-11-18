import 'dart:io';
import 'dart:math';

import 'package:cross_posting_app/features/media/media_probe.dart';
import 'package:cross_posting_app/features/providers/bluesky_photo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Runs Android's photo decoder (MediaProbe.kt) on real files in app storage.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native probe and Bluesky fit handle phone-sized photos', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final dir = Directory(
        '${(await getApplicationSupportDirectory()).path}/photo-native-test',
      )..createSync(recursive: true);
      try {
        // 27 MP: over the bundled decoder's 24 MP budget.
        final huge = File('${dir.path}/huge.jpg')
          ..writeAsBytesSync(
            img.encodeJpg(img.Image(width: 6000, height: 4500), quality: 80),
          );
        final hugeSize = await MediaProbe().inspect(huge.path, 'image/jpeg');
        expect((hugeSize.width, hugeSize.height), (6000, 4500));

        // Noise keeps a 6 MP JPEG over 2 MB; EXIF says "rotate 90".
        final random = Random(3);
        final noise = img.Image(width: 3000, height: 2000);
        for (final pixel in noise) {
          pixel
            ..r = random.nextInt(256)
            ..g = random.nextInt(256)
            ..b = random.nextInt(256);
        }
        noise.exif.imageIfd.orientation = 6;
        final rotated = File('${dir.path}/rotated.jpg')
          ..writeAsBytesSync(img.encodeJpg(noise, quality: 95));
        expect(rotated.lengthSync(), greaterThan(2000000));
        final size = await MediaProbe().inspect(rotated.path, 'image/jpeg');
        expect((size.width, size.height), (2000, 3000));

        final fitted = await fitPhotoForBluesky(
          rotated.path,
          'image/jpeg',
          2000000,
        );
        expect(fitted.mimeType, 'image/jpeg');
        expect(fitted.bytes.length, lessThanOrEqualTo(2000000));
        final out = img.decodeJpg(fitted.bytes)!;
        // Upright (portrait) and within Bluesky's long edge.
        expect(out.height, greaterThan(out.width));
        expect(max(out.width, out.height), lessThanOrEqualTo(2000));
        expect(out.exif.imageIfd.orientation ?? 1, 1);
        expect(rotated.lengthSync(), greaterThan(2000000));

        // A file Android cannot decode is reported, not crashed on.
        final broken = File('${dir.path}/broken.jpg')
          ..writeAsBytesSync([255, 216, 255, 224, 0, 16, 1, 2, 3]);
        await expectLater(
          MediaProbe().inspect(broken.path, 'image/jpeg'),
          throwsA(isA<MediaProbeException>()),
        );
      } finally {
        dir.deleteSync(recursive: true);
      }
    });
  }, timeout: const Timeout(Duration(minutes: 5)));
}
