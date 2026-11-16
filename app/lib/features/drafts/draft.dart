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
abstract class PostContent with _$PostContent {
  const factory PostContent({
    @Default('') String text,
    @Default([]) List<Attachment> media,
  }) = _PostContent;

  factory PostContent.fromJson(Map<String, dynamic> json) =>
      _$PostContentFromJson(json);
}

@freezed
abstract class DestinationVersion with _$DestinationVersion {
  const factory DestinationVersion({
    String? ownText,
    List<Attachment>? ownMedia,
    int? baseTextRevision,
    int? baseMediaRevision,
  }) = _DestinationVersion;

  factory DestinationVersion.fromJson(Map<String, dynamic> json) =>
      _$DestinationVersionFromJson(json);
}

@freezed
abstract class Draft with _$Draft {
  const factory Draft({
    required String id,
    required DateTime updatedAt,
    @Default(0) int revision,
    @Default(0) int sharedTextRevision,
    @Default(0) int sharedMediaRevision,
    @Default(ComposeStage.choose) ComposeStage stage,
    @Default({}) Set<Destination> selected,
    @Default(PostContent()) PostContent shared,
    @Default({}) Map<Destination, DestinationVersion> versions,
    DateTime? deletedAt,
  }) = _Draft;

  factory Draft.fromJson(Map<String, dynamic> json) => _$DraftFromJson(json);
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
