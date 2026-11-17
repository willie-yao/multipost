import 'dart:io';
import 'dart:isolate';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class MediaProbeException implements Exception {
  const MediaProbeException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Local decode safety budgets, independent of any destination/provider limits.
const maxPhotoEncodedBytes = 32 * 1024 * 1024;
const maxPhotoPixels = 24 * 1000 * 1000;

class MediaProbe {
  static const _channel = MethodChannel('org.example.crossposting/media_probe');

  Future<({int width, int height, int? durationMs})> inspect(
    String path,
    String mimeType,
  ) async {
    if (mimeType.startsWith('image/')) {
      return Isolate.run(() {
        final image = decodePhoto(path, mimeType);
        return (width: image.width, height: image.height, durationMs: null);
      });
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'inspect',
        {'path': path, 'mimeType': mimeType},
      );
      final width = result?['width'];
      final height = result?['height'];
      final duration = result?['durationMs'];
      if (width is! int ||
          height is! int ||
          duration is! int ||
          width <= 0 ||
          height <= 0 ||
          duration <= 0) {
        throw const MediaProbeException(
          'Video metadata is unavailable. Replace or remove this item.',
        );
      }
      return (width: width, height: height, durationMs: duration);
    } on PlatformException {
      throw const MediaProbeException(
        'Video metadata is unavailable. Replace or remove this item.',
      );
    } on MissingPluginException {
      throw const MediaProbeException(
        'Video inspection is unavailable on this device.',
      );
    }
  }
}

/// Runs only in a worker isolate. Never use this for video bytes.
img.Image decodePhoto(String path, String mimeType) {
  final file = File(path);
  if (file.lengthSync() > maxPhotoEncodedBytes) {
    throw const MediaProbeException(
      'This photo exceeds the local safe decode budget. Replace or remove it.',
    );
  }
  final bytes = file.readAsBytesSync();
  final img.Decoder decoder = switch (mimeType) {
    'image/png' => img.PngDecoder(maxPixels: maxPhotoPixels),
    'image/jpeg' => img.JpegDecoder(maxPixels: maxPhotoPixels),
    'image/webp' => img.WebPDecoder()..maxPixels = maxPhotoPixels,
    _ => throw const MediaProbeException(
      'This photo format is not supported. Replace or remove it.',
    ),
  };
  try {
    final info = decoder.startDecode(bytes);
    if (info == null ||
        info.width <= 0 ||
        info.height <= 0 ||
        info.width * info.height > maxPhotoPixels) {
      throw const MediaProbeException(
        'This photo cannot be decoded safely. Replace or remove it.',
      );
    }
    if (info.numFrames > 1) {
      throw const MediaProbeException(
        'Animated photos are not supported. Replace or remove this item.',
      );
    }
    final image = decoder.decodeFrame(0);
    if (image == null) {
      throw const MediaProbeException(
        'This photo is damaged. Replace or remove it.',
      );
    }
    return img.bakeOrientation(image);
  } on MediaProbeException {
    rethrow;
  } catch (_) {
    throw const MediaProbeException(
      'This photo is damaged or exceeds the safe decode budget. Replace or remove it.',
    );
  }
}

/// Sniff only a small header; filenames and picker MIME claims are untrusted.
String detectMediaType(Uint8List header) {
  bool starts(List<int> magic) =>
      header.length >= magic.length &&
      List.generate(magic.length, (i) => header[i] == magic[i]).every((v) => v);
  String ascii(int start, int end) => header.length >= end
      ? String.fromCharCodes(header.sublist(start, end))
      : '';
  if (starts([137, 80, 78, 71, 13, 10, 26, 10])) return 'image/png';
  if (starts([255, 216, 255])) return 'image/jpeg';
  if (ascii(0, 4) == 'RIFF' && ascii(8, 12) == 'WEBP') return 'image/webp';
  if (ascii(4, 8) == 'ftyp') {
    // Explicit video container brands; HEIF/AVIF are not video.
    final brand = ascii(8, 12);
    if ({
      'isom',
      'iso2',
      'mp41',
      'mp42',
      'avc1',
      'M4V ',
      'MSNV',
    }.contains(brand)) {
      return 'video/mp4';
    }
    if (brand == 'qt  ') return 'video/quicktime';
  }
  if (starts([0x1a, 0x45, 0xdf, 0xa3])) return 'video/webm';
  throw const MediaProbeException(
    'This media format is not supported. Replace or remove this item.',
  );
}
