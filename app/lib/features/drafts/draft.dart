import 'package:freezed_annotation/freezed_annotation.dart';

part 'draft.freezed.dart';
part 'draft.g.dart';

enum Destination { x, bluesky, instagram }

enum ComposeStage { choose, write, review }

@freezed
abstract class Attachment with _$Attachment {
  const factory Attachment({
    required String assetId,
    @Default('') String altText,
  }) = _Attachment;

  factory Attachment.fromJson(Map<String, dynamic> json) =>
      _$AttachmentFromJson(json);
}

@freezed
@JsonSerializable()
class PostContent with _$PostContent {
  PostContent({this.text = '', List<Attachment> media = const []})
    : media = List<Attachment>.unmodifiable(media);

  const PostContent._empty() : text = '', media = const [];

  final String text;
  final List<Attachment> media;

  factory PostContent.fromJson(Map<String, dynamic> json) =>
      _$PostContentFromJson(json);

  Map<String, dynamic> toJson() => _$PostContentToJson(this);
}

@freezed
@JsonSerializable()
class DestinationVersion with _$DestinationVersion {
  DestinationVersion({
    this.ownText,
    List<Attachment>? ownMedia,
    this.baseTextRevision,
    this.baseMediaRevision,
  }) : ownMedia = ownMedia == null
           ? null
           : List<Attachment>.unmodifiable(ownMedia);

  final String? ownText;
  final List<Attachment>? ownMedia;
  final int? baseTextRevision;
  final int? baseMediaRevision;

  factory DestinationVersion.fromJson(Map<String, dynamic> json) =>
      _$DestinationVersionFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationVersionToJson(this);
}

@freezed
@JsonSerializable()
class Draft with _$Draft {
  Draft({
    required this.id,
    required this.updatedAt,
    this.revision = 0,
    this.sharedTextRevision = 0,
    this.sharedMediaRevision = 0,
    this.stage = ComposeStage.choose,
    Set<Destination> selected = const {},
    this.shared = const PostContent._empty(),
    Map<Destination, DestinationVersion> versions = const {},
    this.deletedAt,
  }) : selected = Set<Destination>.unmodifiable(selected),
       versions = Map<Destination, DestinationVersion>.unmodifiable(versions);

  final String id;
  final DateTime updatedAt;
  final int revision;
  final int sharedTextRevision;
  final int sharedMediaRevision;
  final ComposeStage stage;
  final Set<Destination> selected;
  final PostContent shared;
  final Map<Destination, DestinationVersion> versions;
  final DateTime? deletedAt;

  factory Draft.fromJson(Map<String, dynamic> json) => _$DraftFromJson(json);

  Map<String, dynamic> toJson() => _$DraftToJson(this);
}

@freezed
abstract class MediaAsset with _$MediaAsset {
  const factory MediaAsset({
    required String id,
    required String relativePath,
    required String mimeType,
    required int bytes,
    required String sha256,
    required int width,
    required int height,
    int? durationMs,
    String? originalAssetId,
  }) = _MediaAsset;

  factory MediaAsset.fromJson(Map<String, dynamic> json) =>
      _$MediaAssetFromJson(json);
}
