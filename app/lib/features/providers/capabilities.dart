import 'dart:async';
import 'dart:convert';

import '../drafts/draft.dart';
import '../review/review.dart';
import '../review/review_service.dart';
import 'provider.dart';

enum CapabilityStatus { current, unavailable, superseded }

/// An owned evidence snapshot. A documented limit does not enable a connection.
class ProviderCapabilities {
  ProviderCapabilities({
    required this.destination,
    required this.version,
    required this.verifiedAt,
    required this.text,
    required this.photos,
    required this.video,
    required this.maxPhotos,
    required this.maxTextUnits,
    required this.maxPhotoBytes,
    required this.maxVideoBytes,
    required this.maxVideoDurationMs,
    required Set<String> mimeTypes,
    this.status = CapabilityStatus.unavailable,
    List<Uri> sources = const [],
    this.maxTextBytes,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.minAspectRatio,
    this.maxAspectRatio,
  }) : mimeTypes = Set<String>.unmodifiable(mimeTypes),
       sources = List<Uri>.unmodifiable(sources);

  final Destination destination;
  final String version;
  final DateTime verifiedAt;
  final CapabilityStatus status;
  final bool text, photos, video;
  final int maxPhotos, maxTextUnits, maxPhotoBytes;
  final int maxVideoBytes, maxVideoDurationMs;
  final int? maxTextBytes;
  final Set<String> mimeTypes;
  final List<Uri> sources;
  final int? minWidth, maxWidth, minHeight, maxHeight;
  final double? minAspectRatio, maxAspectRatio;

  /// Documentary snapshots only: official counting, OAuth, account entitlements
  /// and native round trips are not accepted. Never attach a fixture counter.
  factory ProviderCapabilities.documented(Destination destination) {
    if (destination == Destination.instagram) {
      throw ArgumentError('Instagram uses its independent photo policy.');
    }
    final x = destination == Destination.x;
    return ProviderCapabilities(
      destination: destination,
      version: '${x ? 'x-docs' : 'bsky-lexicons'}-2026-11-16;unavailable-1',
      verifiedAt: DateTime.utc(2026, 11, 16),
      text: true,
      photos: true,
      video: false,
      maxPhotos: 4,
      maxTextUnits: x ? 280 : 300,
      maxTextBytes: x ? null : 3000,
      // X's decimal 5 MB ceiling is a conservative app restriction.
      maxPhotoBytes: x ? 5000000 : 2000000,
      maxVideoBytes: 0,
      maxVideoDurationMs: 0,
      mimeTypes: {'image/jpeg', 'image/png'},
      sources: [
        Uri.parse(
          x ? 'https://docs.x.com/fundamentals/counting-characters.md' : 'https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/feed/post.json',
        ),
        Uri.parse(
          x ? 'https://docs.x.com/x-api/media/quickstart/best-practices.md' : 'https://raw.githubusercontent.com/bluesky-social/bsky/main/lexicons/app/bsky/embed/images.json',
        ),
      ],
    );
  }
}

/// Implementations must match the provider's counting rules and conformance
/// data. Grapheme counting alone is not X's weighted twitter-text algorithm.
abstract interface class TextCounter {
  FutureOr<TextMeasurement> measure(String text);
}

class TextMeasurement {
  const TextMeasurement({required this.units, required this.valid});
  final int units;
  final bool valid;
}

class CapabilityValidator implements DestinationValidator {
  CapabilityValidator(this.profile, this.counter);
  final ProviderCapabilities profile;
  final TextCounter counter;
  @override
  String get version => profile.version;

  bool get _usable =>
      profile.status == CapabilityStatus.current &&
      profile.version.trim().isNotEmpty &&
      (!profile.text || profile.maxTextUnits > 0) &&
      (!profile.photos ||
          (profile.maxPhotos > 0 && profile.maxPhotoBytes > 0)) &&
      (!profile.video ||
          (profile.maxVideoBytes > 0 && profile.maxVideoDurationMs > 0)) &&
      (!(profile.photos || profile.video) || profile.mimeTypes.isNotEmpty) &&
      (profile.maxTextBytes == null || profile.maxTextBytes! > 0) &&
      _validRange(profile.minWidth, profile.maxWidth) &&
      _validRange(profile.minHeight, profile.maxHeight) &&
      _validRange(profile.minAspectRatio, profile.maxAspectRatio);

  @override
  Future<List<ReviewIssue>> validate(ResolvedPost post) async {
    ReviewIssue issue(String code, String message) => ReviewIssue(
      destination: post.destination,
      code: code,
      message: message,
      blocking: true,
    );
    if (!_usable || post.destination != profile.destination) {
      return [
        issue('requirements-unverified', "Couldn't check current requirements"),
      ];
    }
    final name = platformName(post.destination);
    final videos = post.assets
        .where((a) => a.mimeType.startsWith('video/'))
        .toList();
    final photos = post.assets
        .where((a) => a.mimeType.startsWith('image/'))
        .toList();
    if (videos.isNotEmpty && !profile.video) {
      return [
        issue(
          'video-unavailable',
          '$name video is not available in this build. Replace it or leave this destination out.',
        ),
      ];
    }
    if (photos.isNotEmpty && !profile.photos) {
      return [
        issue(
          'photos-unavailable',
          '$name photos are not available in this build. Replace them or leave this destination out.',
        ),
      ];
    }
    if (post.assets.length != post.content.media.length ||
        List.generate(post.assets.length, (i) => i).any(
          (i) =>
              i >= post.content.media.length ||
              post.assets[i].id != post.content.media[i].assetId,
        )) {
      return [
        issue(
          'media-unavailable',
          'A reviewed media item is missing or out of order. Review it again.',
        ),
      ];
    }
    final issues = <ReviewIssue>[];
    if (post.content.text.isNotEmpty && !profile.text) {
      issues.add(
        issue('text-unavailable', '$name text is not available in this build.'),
      );
    } else if (profile.text) {
      try {
        final measurement = await counter.measure(post.content.text);
        final units = measurement.units;
        if (units < 0) throw StateError('Invalid counter result');
        if (!measurement.valid &&
            units <= profile.maxTextUnits &&
            post.content.text.isNotEmpty) {
          issues.add(
            issue(
              'text-invalid',
              'Edit the caption; this destination cannot accept this text.',
            ),
          );
        }
        if (units > profile.maxTextUnits) {
          issues.add(
            issue(
              'text-too-long',
              'Shorten the $name caption to ${profile.maxTextUnits} text units.',
            ),
          );
        }
      } catch (_) {
        issues.add(
          issue(
            'requirements-unverified',
            "Couldn't check current requirements",
          ),
        );
      }
    }
    if (profile.maxTextBytes case final limit?) {
      if (utf8.encode(post.content.text).length > limit) {
        issues.add(
          issue(
            'text-bytes-too-large',
            'Shorten the $name caption; it exceeds the UTF-8 byte limit.',
          ),
        );
      }
    }
    if (photos.length > profile.maxPhotos) {
      issues.add(
        issue(
          'photo-count',
          '$name supports at most ${profile.maxPhotos} photos in this profile.',
        ),
      );
    }
    for (final asset in post.assets) {
      final video = asset.mimeType.startsWith('video/');
      final photo = asset.mimeType.startsWith('image/');
      if ((!video && !photo) || !profile.mimeTypes.contains(asset.mimeType)) {
        issues.add(
          issue('mime-unavailable', 'Replace unsupported $name media.'),
        );
        continue;
      }
      if (asset.bytes <= 0 ||
          asset.width <= 0 ||
          asset.height <= 0 ||
          (video && (asset.durationMs == null || asset.durationMs! <= 0))) {
        issues.add(
          issue(
            'media-metadata-unavailable',
            'A media item could not be checked. Replace it before publishing to $name.',
          ),
        );
        continue;
      }
      if (asset.bytes >
          (video ? profile.maxVideoBytes : profile.maxPhotoBytes)) {
        issues.add(
          issue(
            video ? 'video-bytes-too-large' : 'photo-bytes-too-large',
            'Choose a smaller media file for $name.',
          ),
        );
      }
      if (video && asset.durationMs! > profile.maxVideoDurationMs) {
        issues.add(
          issue('video-duration-too-long', 'Choose a shorter video for $name.'),
        );
      }
      if (!_within(asset.width, profile.minWidth, profile.maxWidth) ||
          !_within(asset.height, profile.minHeight, profile.maxHeight)) {
        issues.add(
          issue(
            'media-dimensions',
            'Choose media with supported dimensions for $name.',
          ),
        );
      }
      if (!_within(
        asset.width / asset.height,
        profile.minAspectRatio,
        profile.maxAspectRatio,
      )) {
        issues.add(
          issue(
            'media-aspect',
            'Choose media with a supported aspect ratio for $name.',
          ),
        );
      }
    }
    return List<ReviewIssue>.unmodifiable(issues);
  }
}

bool _validRange(num? min, num? max) =>
    (min == null || (min.isFinite && min > 0)) &&
    (max == null || (max.isFinite && max > 0)) &&
    (min == null || max == null || min <= max);
bool _within(num value, num? min, num? max) =>
    (min == null || value >= min) && (max == null || value <= max);

class CapabilityRegistry implements ValidatorRegistry {
  CapabilityRegistry(Map<Destination, DestinationValidator> validators)
    : _validators = Map<Destination, DestinationValidator>.unmodifiable(
        validators,
      );
  final Map<Destination, DestinationValidator> _validators;

  factory CapabilityRegistry.production({
    required DestinationValidator instagram,
  }) => CapabilityRegistry({
    Destination.instagram: instagram,
    for (final destination in [Destination.x, Destination.bluesky])
      destination: CapabilityValidator(
        ProviderCapabilities.documented(destination),
        const _UnavailableCounter(),
      ),
  });

  @override
  DestinationValidator forDestination(Destination destination) =>
      _validators[destination] ??
      const LocalValidators().forDestination(destination);
}

class _UnavailableCounter implements TextCounter {
  const _UnavailableCounter();
  @override
  TextMeasurement measure(String text) =>
      throw StateError('Official text counter not accepted');
}
