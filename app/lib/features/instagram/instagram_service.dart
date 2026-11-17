import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import '../../core/clock.dart';
import '../../core/ids.dart';
import '../../storage/media_files.dart';
import '../drafts/draft.dart';
import '../media/media_probe.dart';
import '../review/review.dart';
import '../review/review_service.dart';
import 'instagram_package.dart';
import 'instagram_repository.dart';

/// Evidence for *local preparation*, never receiving-app or publication proof.
class InstagramPhotoPolicy implements DestinationValidator {
  InstagramPhotoPolicy({
    required this.preparationVerified,
    required this.maxPhotos,
    required Set<String> mimeTypes,
    required this.evidenceVersion,
  }) : mimeTypes = Set<String>.unmodifiable(mimeTypes);

  /// JPEG/PNG are this app's supported local formats. Count 20 is documented
  /// in official Help Center metadata (269314186824048), accessed 2026-11-16.
  /// Personal-app MIME/aspect/byte/intent acceptance remains unverified.
  factory InstagramPhotoPolicy.localPreparation() => InstagramPhotoPolicy(
    preparationVerified: true,
    maxPhotos: 20,
    mimeTypes: {'image/jpeg', 'image/png'},
    evidenceVersion:
        'local-jpeg-png-1;ig-help-269314186824048-metadata-2026-11-16-count20',
  );
  final bool preparationVerified;
  final int maxPhotos;
  final Set<String> mimeTypes;
  final String evidenceVersion;
  @override
  String get version => evidenceVersion;

  @override
  List<ReviewIssue> validate(ResolvedPost post) {
    ReviewIssue issue(String code, String message) => ReviewIssue(
      destination: Destination.instagram,
      code: code,
      message: message,
      blocking: true,
    );
    return [
      if (!preparationVerified ||
          evidenceVersion.trim().isEmpty ||
          maxPhotos <= 0 ||
          mimeTypes.isEmpty)
        issue(
          'preparation-unverified',
          'Local photo preparation could not be checked. Keep your draft and try again.',
        ),
      if (post.destination != Destination.instagram)
        issue(
          'instagram-not-selected',
          'Choose Instagram before preparing photos.',
        ),
      if (post.content.media.isEmpty)
        issue('instagram-photos-required', 'Choose photos for Instagram.'),
      if (post.content.media.length > maxPhotos)
        issue(
          'instagram-photo-count',
          'Prepare at most $maxPhotos photos in one package.',
        ),
      if (post.assets.any((a) => !a.mimeType.startsWith('image/')))
        issue(
          'instagram-photos-only',
          'Instagram preparation supports photos only. Choose own photos or leave Instagram out; shared video stays in your draft.',
        ),
      if (post.assets.any((a) => !mimeTypes.contains(a.mimeType)))
        issue(
          'instagram-local-format',
          'Local preparation supports JPEG and PNG photos. Replace unsupported media.',
        ),
      if (post.assets.length != post.content.media.length ||
          List.generate(post.assets.length, (i) => i).any(
            (i) =>
                i >= post.content.media.length ||
                post.assets[i].id != post.content.media[i].assetId,
          ))
        issue(
          'instagram-media-unavailable',
          'A reviewed photo is unavailable or out of order. Review it again.',
        ),
    ];
  }
}

/// Direct providers keep their existing conservative validators/readiness.
class InstagramPreparationValidators implements ValidatorRegistry {
  InstagramPreparationValidators(this.policy);
  final InstagramPhotoPolicy policy;
  @override
  DestinationValidator forDestination(Destination destination) =>
      destination == Destination.instagram
      ? policy
      : const LocalValidators().forDestination(destination);
}

class InstagramPreparationRejected implements Exception {
  InstagramPreparationRejected(List<ReviewIssue> issues)
    : issues = List<ReviewIssue>.unmodifiable(issues);
  final List<ReviewIssue> issues;
  @override
  String toString() => issues.map((i) => i.message).join(' ');
}

class InstagramPreparationException implements Exception {
  const InstagramPreparationException(this.message, {this.photoOrdinal});
  final String message;
  final int? photoOrdinal;
  @override
  String toString() => message;
}

bool samePackageSource(InstagramPackage package, ReviewedPost reviewed) {
  final post = reviewed.posts[Destination.instagram];
  if (post == null ||
      package.draftId != reviewed.draftId ||
      package.revision != reviewed.revision ||
      package.caption != post.content.text ||
      package.ownCaption != post.ownCaption ||
      package.photos.length != post.assets.length ||
      post.content.media.length != post.assets.length) {
    return false;
  }
  for (var i = 0; i < package.photos.length; i++) {
    final photo = package.photos[i];
    final asset = post.assets[i];
    final attachment = post.content.media[i];
    if (photo.ordinal != i + 1 ||
        photo.assetId != asset.id ||
        attachment.assetId != asset.id ||
        photo.sha256 != asset.sha256 ||
        photo.altText != attachment.altText) {
      return false;
    }
  }
  return true;
}

class InstagramService {
  InstagramService(
    this.repository,
    this.media,
    this.root,
    this.policy,
    this.ids,
    this.clock,
  );
  final InstagramRepository repository;
  final MediaFiles media;

  /// Explicit application-support/instagram-packages composition, never media-derived.
  final Directory root;
  final InstagramPhotoPolicy policy;
  final Ids ids;
  final Clock clock;
  final _preparing = <String, Future<InstagramPackage>>{};

  Future<InstagramPackage> prepare(
    ReviewedPost reviewed, {
    required String operationId,
  }) async {
    if (operationId.trim().isEmpty) {
      throw ArgumentError.value(operationId, 'operationId');
    }
    final inFlight = _preparing[operationId];
    if (inFlight != null) {
      final package = await inFlight;
      if (!samePackageSource(package, reviewed)) {
        throw StateError('Preparation changed');
      }
      return package;
    }
    final operation = _prepare(reviewed, operationId);
    _preparing[operationId] = operation;
    try {
      return await operation;
    } finally {
      _preparing.remove(operationId);
    }
  }

  Future<InstagramPackage> _prepare(
    ReviewedPost reviewed,
    String operationId,
  ) async {
    final existing = await repository.findByOperation(operationId);
    if (existing != null) {
      if (!samePackageSource(existing, reviewed)) {
        throw StateError('Preparation changed');
      }
      for (final photo in existing.photos) {
        await fileFor(existing, photo);
      }
      return existing;
    }
    final post = reviewed.posts[Destination.instagram];
    if (post == null) throw StateError('Instagram is not selected');
    final issues = policy.validate(post);
    if (issues.any((i) => i.blocking)) {
      throw InstagramPreparationRejected(issues);
    }
    if (reviewed.capabilityVersions[Destination.instagram] != policy.version) {
      throw const StaleReviewException();
    }
    final id = ids.next();
    if (!RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    ).hasMatch(id)) {
      throw StateError('Unsafe package identifier');
    }
    Directory? owned;
    String? privateRoot;
    var ordinal = 1;
    var recorded = false;
    try {
      await root.create(recursive: true);
      privateRoot = await root.resolveSymbolicLinks();
      final staging = Directory(p.join(privateRoot, '.$id.preparing'));
      final finalDirectory = Directory(p.join(privateRoot, id));
      if (await FileSystemEntity.type(staging.path, followLinks: false) !=
              FileSystemEntityType.notFound ||
          await FileSystemEntity.type(
                finalDirectory.path,
                followLinks: false,
              ) !=
              FileSystemEntityType.notFound) {
        throw StateError('Package identifier already exists');
      }
      await staging.create();
      owned = staging;
      final photos = <PreparedPhoto>[];
      for (var index = 0; index < post.assets.length; index++) {
        ordinal = index + 1;
        final asset = post.assets[index];
        if (await media.find(asset.id) != asset) throw const FormatException();
        final source = await media.fileFor(asset.id);
        final extension = asset.mimeType == 'image/png' ? 'png' : 'jpg';
        final name = '${ordinal.toString().padLeft(2, '0')}.$extension';
        final destination = File(p.join(staging.path, name));
        await destination.create(exclusive: true);
        final output = await destination.open(mode: FileMode.writeOnly);
        try {
          await for (final bytes in source.openRead()) {
            await output.writeFrom(bytes);
          }
          await output.flush();
        } finally {
          await output.close();
        }
        await _checkPhoto(
          destination,
          expectedHash: asset.sha256,
          expectedBytes: asset.bytes,
          expectedMime: asset.mimeType,
          width: asset.width,
          height: asset.height,
        );
        if (await media.find(asset.id) != asset) throw const FormatException();
        photos.add(
          PreparedPhoto(
            assetId: asset.id,
            relativePath: '$id/$name',
            sha256: asset.sha256,
            ordinal: ordinal,
            altText: post.content.media[index].altText,
          ),
        );
      }
      owned = await staging.rename(finalDirectory.path);
      final package = InstagramPackage(
        id: id,
        operationId: operationId,
        draftId: reviewed.draftId,
        revision: reviewed.revision,
        caption: post.content.text,
        ownCaption: post.ownCaption,
        photos: photos,
        createdAt: clock.now(),
      );
      try {
        await repository.create(package);
      } catch (_) {
        // A second service/process can win the unique operation key. Its source
        // must agree; the loser discards only its own unpublished directory.
        final winner = await repository.findByOperation(operationId);
        if (winner == null) rethrow;
        if (!samePackageSource(winner, reviewed)) {
          throw StateError('Preparation changed');
        }
        for (final photo in winner.photos) {
          await fileFor(winner, photo);
        }
        return winner;
      }
      recorded = true;
      return package;
    } on StateError {
      rethrow;
    } on StaleReviewException {
      rethrow;
    } catch (_) {
      throw InstagramPreparationException(
        'Photo $ordinal could not be prepared on this device. Your draft and earlier prepared versions are kept. Check storage or replace this photo, then try again.',
        photoOrdinal: ordinal,
      );
    } finally {
      if (!recorded && owned != null && privateRoot != null) {
        // Never sweep unrelated/orphan packages: only this operation's directory.
        final absolute = p.normalize(p.absolute(owned.path));
        if (p.isWithin(privateRoot, absolute) &&
            await owned.exists() &&
            p.isWithin(privateRoot, await owned.resolveSymbolicLinks())) {
          try {
            await owned.delete(recursive: true);
          } on FileSystemException {
            /* A kept orphan is not a ready package. */
          }
        }
      }
    }
  }

  /// Read frozen files independently of source assets or a deleted draft.
  Future<File> fileFor(InstagramPackage package, PreparedPhoto photo) async {
    try {
      if (!package.photos.contains(photo) ||
          await repository.get(package.id) != package) {
        throw const FormatException();
      }
      final privateRoot = await root.resolveSymbolicLinks();
      final relative = photo.relativePath;
      final path = p.normalize(p.join(privateRoot, relative));
      if (p.isAbsolute(relative) ||
          p.split(relative).contains('..') ||
          !p.isWithin(privateRoot, path) ||
          p.split(relative).first != package.id) {
        throw const FormatException();
      }
      final file = File(path);
      if (!p.isWithin(privateRoot, await file.resolveSymbolicLinks())) {
        throw const FormatException();
      }
      await _checkPhoto(
        file,
        expectedHash: photo.sha256,
        expectedMime: relative.endsWith('.png') ? 'image/png' : 'image/jpeg',
      );
      return file;
    } catch (_) {
      throw InstagramPreparationException(
        'Prepared photo ${photo.ordinal} is missing or damaged. Keep this package; prepare an updated version from your draft if available.',
        photoOrdinal: photo.ordinal,
      );
    }
  }

  Future<void> _checkPhoto(
    File file, {
    required String expectedHash,
    required String expectedMime,
    int? expectedBytes,
    int? width,
    int? height,
  }) async {
    if (expectedBytes != null && await file.length() != expectedBytes) {
      throw const FormatException();
    }
    if ((await sha256.bind(file.openRead()).first).toString() != expectedHash) {
      throw const FormatException();
    }
    final input = await file.open();
    try {
      if (detectMediaType(await input.read(64)) != expectedMime) {
        throw const FormatException();
      }
    } finally {
      await input.close();
    }
    final metadata = await MediaProbe().inspect(file.path, expectedMime);
    if ((width != null && metadata.width != width) ||
        (height != null && metadata.height != height) ||
        metadata.durationMs != null) {
      throw const FormatException();
    }
  }
}
