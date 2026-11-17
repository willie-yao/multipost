import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import 'instagram_package.dart';

class PhotoSaveResult {
  const PhotoSaveResult({required this.ordinal, this.uri, this.errorCode});
  final int ordinal;
  final String? uri;
  final String? errorCode;
  bool get succeeded => uri != null && errorCode == null;
}

/// One durable identity per package photo, reused across crash recovery/retries.
class PhotoExportJob {
  const PhotoExportJob({
    required this.id,
    required this.packageId,
    required this.ordinal,
    this.uri,
    this.completed = false,
    this.receiptEventId,
  });
  final String id;
  final String packageId;
  final int ordinal;
  final String? uri;
  final bool completed;

  /// Latest append-ordered receipt activity, derived from the event journal.
  /// Compared inside SQLite before applying an awaited native result.
  final String? receiptEventId;
}

abstract interface class AndroidTransfer {
  Future<void> copyCaption(String caption);
  Future<List<PhotoSaveResult>> savePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  );

  /// Checks only existing jobs; never starts a new export.
  Future<List<PhotoSaveResult>> reconcilePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  );
}

class MethodChannelAndroidTransfer implements AndroidTransfer {
  MethodChannelAndroidTransfer(this.root);
  final Directory root;
  static const channel = MethodChannel('crossposting/instagram');
  @override
  Future<void> copyCaption(String caption) =>
      Clipboard.setData(ClipboardData(text: caption));

  Map<String, Object> _arguments(InstagramPackage package, PhotoExportJob job) {
    if (job.packageId != package.id) throw StateError('Export package changed');
    final photo = package.photos.singleWhere((p) => p.ordinal == job.ordinal);
    final extension = p.extension(photo.relativePath);
    return {
      'jobId': job.id,
      'sourcePath': p.join(root.absolute.path, photo.relativePath),
      'displayName':
          'caption-${job.id}-${job.ordinal.toString().padLeft(2, '0')}$extension',
      'mimeType': extension == '.png' ? 'image/png' : 'image/jpeg',
      'expectedHash': photo.sha256,
    };
  }

  void _validateJobs(InstagramPackage package, List<PhotoExportJob> jobs) {
    final ordinals = <int>{};
    final ids = <String>{};
    for (final job in jobs) {
      if (job.packageId != package.id ||
          !ordinals.add(job.ordinal) ||
          !ids.add(job.id) ||
          !package.photos.any((photo) => photo.ordinal == job.ordinal) ||
          !RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(job.id)) {
        throw StateError('Export jobs do not match this prepared package.');
      }
    }
  }

  Future<PhotoSaveResult> _invoke(
    String method,
    InstagramPackage package,
    PhotoExportJob job,
  ) async {
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(
        method,
        _arguments(package, job),
      );
      final uri = result?['uri'];
      if (uri == null && method == 'reconcilePhoto') {
        return PhotoSaveResult(ordinal: job.ordinal, errorCode: 'missing');
      }
      if (uri is! String ||
          Uri.tryParse(uri)?.scheme != 'content' ||
          Uri.tryParse(uri)?.authority.isEmpty != false) {
        return PhotoSaveResult(
          ordinal: job.ordinal,
          errorCode: 'invalid-receipt',
        );
      }
      return PhotoSaveResult(ordinal: job.ordinal, uri: uri);
    } on PlatformException catch (error) {
      return PhotoSaveResult(ordinal: job.ordinal, errorCode: error.code);
    } on MissingPluginException {
      return PhotoSaveResult(
        ordinal: job.ordinal,
        errorCode: 'android-unavailable',
      );
    }
  }

  @override
  Future<List<PhotoSaveResult>> savePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) async {
    _validateJobs(package, jobs);
    return [for (final job in jobs) await _invoke('savePhoto', package, job)];
  }

  @override
  Future<List<PhotoSaveResult>> reconcilePhotos(
    InstagramPackage package,
    List<PhotoExportJob> jobs,
  ) async {
    _validateJobs(package, jobs);
    return [
      for (final job in jobs) await _invoke('reconcilePhoto', package, job),
    ];
  }
}
