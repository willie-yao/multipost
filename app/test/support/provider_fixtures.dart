import 'package:characters/characters.dart';
import 'package:cross_posting_app/features/accounts/account.dart';
import 'package:cross_posting_app/features/drafts/draft.dart';
import 'package:cross_posting_app/features/providers/capabilities.dart';
import 'package:cross_posting_app/features/review/review.dart';

// Deliberately tiny, fake limits. Never imported into production.
ProviderCapabilities fixtureCapabilities({
  Destination destination = Destination.bluesky,
  bool text = true,
  bool photos = true,
  bool video = true,
  CapabilityStatus status = CapabilityStatus.current,
  Set<String>? mimeTypes,
  int? maxTextBytes,
  int? minWidth,
  int? maxWidth,
  int? minHeight,
  int? maxHeight,
  double? minAspectRatio,
  double? maxAspectRatio,
}) => ProviderCapabilities(
  destination: destination,
  version: 'FAKE-fixture-only-1',
  verifiedAt: DateTime.utc(2026, 11, 16),
  status: status,
  text: text,
  photos: photos,
  video: video,
  maxPhotos: 2,
  maxTextUnits: 20,
  maxTextBytes: maxTextBytes,
  maxPhotoBytes: 100,
  maxVideoBytes: 200,
  maxVideoDurationMs: 1000,
  mimeTypes: mimeTypes ?? {'image/png', 'video/mp4'},
  minWidth: minWidth,
  maxWidth: maxWidth,
  minHeight: minHeight,
  maxHeight: maxHeight,
  minAspectRatio: minAspectRatio,
  maxAspectRatio: maxAspectRatio,
);

// Fixture graphemes only. This is explicitly not production X counting.
class FixtureTextCounter implements TextCounter {
  @override
  int count(String text) => text.characters.length;
}

MediaAsset fixtureAsset({
  String id = 'local-photo',
  String mimeType = 'image/png',
  int bytes = 100,
  int width = 8,
  int height = 6,
  int? durationMs,
}) => MediaAsset(
  id: id,
  relativePath: 'assets/$id',
  mimeType: mimeType,
  bytes: bytes,
  width: width,
  height: height,
  durationMs: durationMs,
  sha256: 'fixture-content-hash',
);

ResolvedPost fixturePost({
  Destination destination = Destination.bluesky,
  String text = 'caption',
  List<MediaAsset> assets = const [],
}) => ResolvedPost(
  destination: destination,
  ownCaption: false,
  content: PostContent(
    text: text,
    media: [for (final asset in assets) Attachment(assetId: asset.id)],
  ),
  assets: assets,
  account: AccountIdentity(
    destination: destination,
    subject: destination == Destination.x ? '12345' : 'did:plc:fixture-person',
    handle: '@fixture.test',
  ),
);

ResolvedPost fixtureVideoPost(Destination destination) => fixturePost(
  destination: destination,
  assets: [
    fixtureAsset(
      id: 'local-video',
      mimeType: 'video/mp4',
      bytes: 200,
      durationMs: 1000,
    ),
  ],
);
