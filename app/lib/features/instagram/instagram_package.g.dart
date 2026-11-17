// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instagram_package.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstagramPackage _$InstagramPackageFromJson(Map<String, dynamic> json) =>
    InstagramPackage(
      id: json['id'] as String,
      operationId: json['operationId'] as String,
      draftId: json['draftId'] as String,
      revision: (json['revision'] as num).toInt(),
      caption: json['caption'] as String,
      ownCaption: json['ownCaption'] as bool,
      photos: (json['photos'] as List<dynamic>)
          .map((e) => PreparedPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$InstagramPackageToJson(InstagramPackage instance) =>
    <String, dynamic>{
      'id': instance.id,
      'operationId': instance.operationId,
      'draftId': instance.draftId,
      'revision': instance.revision,
      'caption': instance.caption,
      'ownCaption': instance.ownCaption,
      'photos': instance.photos.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
    };

InstagramProgress _$InstagramProgressFromJson(Map<String, dynamic> json) =>
    InstagramProgress(
      state: $enumDecode(_$InstagramStateEnumMap, json['state']),
      priorPending: $enumDecodeNullable(
        _$InstagramStateEnumMap,
        json['priorPending'],
      ),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.parse(json['confirmedAt'] as String),
      activeLaunchId: json['activeLaunchId'] as String?,
      promptedLaunchId: json['promptedLaunchId'] as String?,
      savedUris:
          (json['savedUris'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(int.parse(k), e as String),
          ) ??
          const {},
    );

Map<String, dynamic> _$InstagramProgressToJson(InstagramProgress instance) =>
    <String, dynamic>{
      'state': _$InstagramStateEnumMap[instance.state]!,
      'priorPending': _$InstagramStateEnumMap[instance.priorPending],
      'confirmedAt': instance.confirmedAt?.toIso8601String(),
      'activeLaunchId': instance.activeLaunchId,
      'promptedLaunchId': instance.promptedLaunchId,
      'savedUris': instance.savedUris.map((k, e) => MapEntry(k.toString(), e)),
    };

const _$InstagramStateEnumMap = {
  InstagramState.preparing: 'preparing',
  InstagramState.ready: 'ready',
  InstagramState.handedOff: 'handedOff',
  InstagramState.userMarked: 'userMarked',
};

_PreparedPhoto _$PreparedPhotoFromJson(Map<String, dynamic> json) =>
    _PreparedPhoto(
      assetId: json['assetId'] as String,
      relativePath: json['relativePath'] as String,
      sha256: json['sha256'] as String,
      ordinal: (json['ordinal'] as num).toInt(),
      altText: json['altText'] as String,
    );

Map<String, dynamic> _$PreparedPhotoToJson(_PreparedPhoto instance) =>
    <String, dynamic>{
      'assetId': instance.assetId,
      'relativePath': instance.relativePath,
      'sha256': instance.sha256,
      'ordinal': instance.ordinal,
      'altText': instance.altText,
    };

_InstagramEvent _$InstagramEventFromJson(Map<String, dynamic> json) =>
    _InstagramEvent(
      id: json['id'] as String,
      kind: $enumDecode(_$InstagramEventKindEnumMap, json['kind']),
      at: DateTime.parse(json['at'] as String),
      photoOrdinal: (json['photoOrdinal'] as num?)?.toInt(),
      uri: json['uri'] as String?,
      launchId: json['launchId'] as String?,
      targetPackage: json['targetPackage'] as String?,
    );

Map<String, dynamic> _$InstagramEventToJson(_InstagramEvent instance) =>
    <String, dynamic>{
      'id': instance.id,
      'kind': _$InstagramEventKindEnumMap[instance.kind]!,
      'at': instance.at.toIso8601String(),
      'photoOrdinal': instance.photoOrdinal,
      'uri': instance.uri,
      'launchId': instance.launchId,
      'targetPackage': instance.targetPackage,
    };

const _$InstagramEventKindEnumMap = {
  InstagramEventKind.captionCopied: 'captionCopied',
  InstagramEventKind.photoSaved: 'photoSaved',
  InstagramEventKind.opened: 'opened',
  InstagramEventKind.chooserOpened: 'chooserOpened',
  InstagramEventKind.targetDispatched: 'targetDispatched',
  InstagramEventKind.returnAcknowledged: 'returnAcknowledged',
  InstagramEventKind.markedPosted: 'markedPosted',
  InstagramEventKind.markUndone: 'markUndone',
};
