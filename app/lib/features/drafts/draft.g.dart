// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PostContent _$PostContentFromJson(Map<String, dynamic> json) => PostContent(
  text: json['text'] as String? ?? '',
  media:
      (json['media'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$PostContentToJson(PostContent instance) =>
    <String, dynamic>{
      'text': instance.text,
      'media': instance.media.map((e) => e.toJson()).toList(),
    };

DestinationVersion _$DestinationVersionFromJson(Map<String, dynamic> json) =>
    DestinationVersion(
      ownText: json['ownText'] as String?,
      ownMedia: (json['ownMedia'] as List<dynamic>?)
          ?.map((e) => Attachment.fromJson(e as Map<String, dynamic>))
          .toList(),
      baseTextRevision: (json['baseTextRevision'] as num?)?.toInt(),
      baseMediaRevision: (json['baseMediaRevision'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DestinationVersionToJson(DestinationVersion instance) =>
    <String, dynamic>{
      'ownText': instance.ownText,
      'ownMedia': instance.ownMedia?.map((e) => e.toJson()).toList(),
      'baseTextRevision': instance.baseTextRevision,
      'baseMediaRevision': instance.baseMediaRevision,
    };

Draft _$DraftFromJson(Map<String, dynamic> json) => Draft(
  id: json['id'] as String,
  updatedAt: DateTime.parse(json['updatedAt'] as String),
  revision: (json['revision'] as num?)?.toInt() ?? 0,
  sharedTextRevision: (json['sharedTextRevision'] as num?)?.toInt() ?? 0,
  sharedMediaRevision: (json['sharedMediaRevision'] as num?)?.toInt() ?? 0,
  stage:
      $enumDecodeNullable(_$ComposeStageEnumMap, json['stage']) ??
      ComposeStage.choose,
  selected:
      (json['selected'] as List<dynamic>?)
          ?.map((e) => $enumDecode(_$DestinationEnumMap, e))
          .toSet() ??
      const {},
  shared: json['shared'] == null
      ? const PostContent._empty()
      : PostContent.fromJson(json['shared'] as Map<String, dynamic>),
  versions:
      (json['versions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(
          $enumDecode(_$DestinationEnumMap, k),
          DestinationVersion.fromJson(e as Map<String, dynamic>),
        ),
      ) ??
      const {},
  deletedAt: json['deletedAt'] == null
      ? null
      : DateTime.parse(json['deletedAt'] as String),
);

Map<String, dynamic> _$DraftToJson(Draft instance) => <String, dynamic>{
  'id': instance.id,
  'updatedAt': instance.updatedAt.toIso8601String(),
  'revision': instance.revision,
  'sharedTextRevision': instance.sharedTextRevision,
  'sharedMediaRevision': instance.sharedMediaRevision,
  'stage': _$ComposeStageEnumMap[instance.stage]!,
  'selected': instance.selected.map((e) => _$DestinationEnumMap[e]!).toList(),
  'shared': instance.shared.toJson(),
  'versions': instance.versions.map(
    (k, e) => MapEntry(_$DestinationEnumMap[k]!, e.toJson()),
  ),
  'deletedAt': instance.deletedAt?.toIso8601String(),
};

const _$ComposeStageEnumMap = {
  ComposeStage.choose: 'choose',
  ComposeStage.write: 'write',
  ComposeStage.review: 'review',
};

const _$DestinationEnumMap = {
  Destination.x: 'x',
  Destination.bluesky: 'bluesky',
  Destination.instagram: 'instagram',
};

_Attachment _$AttachmentFromJson(Map<String, dynamic> json) => _Attachment(
  assetId: json['assetId'] as String,
  altText: json['altText'] as String? ?? '',
);

Map<String, dynamic> _$AttachmentToJson(_Attachment instance) =>
    <String, dynamic>{'assetId': instance.assetId, 'altText': instance.altText};

_MediaAsset _$MediaAssetFromJson(Map<String, dynamic> json) => _MediaAsset(
  id: json['id'] as String,
  relativePath: json['relativePath'] as String,
  mimeType: json['mimeType'] as String,
  bytes: (json['bytes'] as num).toInt(),
  sha256: json['sha256'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
  durationMs: (json['durationMs'] as num?)?.toInt(),
  originalAssetId: json['originalAssetId'] as String?,
);

Map<String, dynamic> _$MediaAssetToJson(_MediaAsset instance) =>
    <String, dynamic>{
      'id': instance.id,
      'relativePath': instance.relativePath,
      'mimeType': instance.mimeType,
      'bytes': instance.bytes,
      'sha256': instance.sha256,
      'width': instance.width,
      'height': instance.height,
      'durationMs': instance.durationMs,
      'originalAssetId': instance.originalAssetId,
    };
