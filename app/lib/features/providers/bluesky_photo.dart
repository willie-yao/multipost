import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../media/media_probe.dart';

/// The bytes Bluesky receives for one reviewed photo.
class FittedPhoto {
  const FittedPhoto(this.bytes, this.mimeType);
  final Uint8List bytes;
  final String mimeType;
}

/// Returns the reviewed photo unchanged when it is within [maxBytes]; otherwise
/// a smaller JPEG copy of the same picture (long edge 2000 px or less, no
/// metadata). Deterministic, so a retry uploads identical bytes. The reviewed
/// file on this device is never modified.
Future<FittedPhoto> fitPhotoForBluesky(
  String path,
  String mimeType,
  int maxBytes,
) async {
  final file = File(path);
  if (await file.length() <= maxBytes) {
    return FittedPhoto(await file.readAsBytes(), mimeType);
  }
  return Isolate.run(() => fitPhotoSync(path, mimeType, maxBytes));
}

/// Runs only in a worker isolate.
FittedPhoto fitPhotoSync(String path, String mimeType, int maxBytes) {
  var image = decodePhoto(path, mimeType);
  if (image.hasAlpha) {
    // JPEG has no transparency; flatten onto white instead of black.
    final flat = img.Image(width: image.width, height: image.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, image);
    image = flat;
  }
  image.exif = img.ExifData();
  image.textData = null;
  for (final edge in const [2000, 1600, 1200, 1000]) {
    final long = math.max(image.width, image.height);
    final scaled = long <= edge
        ? image
        : img.copyResize(
            image,
            width: image.width >= image.height ? edge : null,
            height: image.width >= image.height ? null : edge,
            interpolation: img.Interpolation.average,
          );
    for (final quality in const [90, 80, 70]) {
      final bytes = img.encodeJpg(scaled, quality: quality);
      if (bytes.length <= maxBytes) return FittedPhoto(bytes, 'image/jpeg');
    }
  }
  throw const MediaProbeException(
    'This photo could not be made small enough for Bluesky. Replace it.',
  );
}
