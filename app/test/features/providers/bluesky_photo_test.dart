import 'dart:io';
import 'dart:math';

import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/bluesky_photo.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../support/provider_fixtures.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('bsky-photo'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Random noise does not compress, so a phone-sized PNG stays large.
  File noisePng(int width, int height, {bool alpha = false}) {
    final random = Random(7);
    final image = img.Image(
      width: width,
      height: height,
      numChannels: alpha ? 4 : 3,
    );
    for (final pixel in image) {
      pixel
        ..r = random.nextInt(256)
        ..g = random.nextInt(256)
        ..b = random.nextInt(256);
      if (alpha) pixel.a = 0;
    }
    return File('${dir.path}/${alpha ? 'clear' : 'noise'}.png')
      ..writeAsBytesSync(img.encodePng(image));
  }

  test('a photo within the limit is uploaded unchanged', () async {
    final file = noisePng(40, 30);
    final fitted = await fitPhotoForBluesky(file.path, 'image/png', 2000000);
    expect(fitted.mimeType, 'image/png');
    expect(fitted.bytes, file.readAsBytesSync());
  });

  test(
    'a large phone photo becomes a smaller JPEG within the limit',
    () async {
      final file = noisePng(2400, 1800);
      expect(file.lengthSync(), greaterThan(2000000));
      final fitted = await fitPhotoForBluesky(file.path, 'image/png', 2000000);
      expect(fitted.mimeType, 'image/jpeg');
      expect(fitted.bytes.length, lessThanOrEqualTo(2000000));
      final decoded = img.decodeJpg(fitted.bytes)!;
      expect(max(decoded.width, decoded.height), lessThanOrEqualTo(2000));
      expect(decoded.width / decoded.height, closeTo(2400 / 1800, 0.01));
      // Retries upload identical bytes.
      final again = await fitPhotoForBluesky(file.path, 'image/png', 2000000);
      expect(again.bytes, fitted.bytes);
      // The reviewed file on the device is untouched.
      expect(file.lengthSync(), greaterThan(2000000));
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('transparent areas are flattened onto white, not black', () {
    final file = noisePng(64, 64, alpha: true);
    final fitted = fitPhotoSync(file.path, 'image/png', 2000);
    final pixel = img.decodeJpg(fitted.bytes)!.getPixel(10, 10);
    expect(pixel.r, greaterThan(240));
    expect(pixel.g, greaterThan(240));
    expect(pixel.b, greaterThan(240));
  });

  test('Review notes, but does not block, a photo over 2 MB', () async {
    final validator = BlueskyValidator(
      ProviderCapabilities.documented(Destination.bluesky, devAccepted: true),
    );
    final issues = await validator.validate(
      fixturePost(
        assets: [
          fixtureAsset(id: 'big', mimeType: 'image/jpeg', bytes: 4800000),
        ],
      ),
    );
    expect(issues.where((i) => i.blocking), isEmpty);
    expect(issues.map((i) => i.code), ['photo-sent-smaller']);
  });

  test('the sign-in return opens in the app task so the tab closes', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final callback = RegExp(
      r'<activity android:name="com\.linusu\.flutter_web_auth_2\.CallbackActivity"[^>]*>',
    ).firstMatch(manifest)!.group(0)!;
    expect(callback, contains('android:taskAffinity=""'));
  });
}
