import 'package:freezed_annotation/freezed_annotation.dart';

part 'instagram_package.freezed.dart';
part 'instagram_package.g.dart';

enum InstagramState { preparing, ready, handedOff, userMarked }

enum InstagramEventKind {
  captionCopied,
  photoSaved,
  photoUnavailable,
  opened,
  chooserOpened,
  targetDispatched,
  returnAcknowledged,
  markedPosted,
  markUndone,
}

@freezed
abstract class PreparedPhoto with _$PreparedPhoto {
  const factory PreparedPhoto({
    required String assetId,
    required String relativePath,
    required String sha256,
    required int ordinal,
    required String altText,
  }) = _PreparedPhoto;
  factory PreparedPhoto.fromJson(Map<String, dynamic> json) =>
      _$PreparedPhotoFromJson(json);
}

@freezed
@JsonSerializable()
class InstagramPackage with _$InstagramPackage {
  InstagramPackage({
    required this.id,
    required this.operationId,
    required this.draftId,
    required this.revision,
    required this.caption,
    required this.ownCaption,
    required List<PreparedPhoto> photos,
    required this.createdAt,
  }) : photos = List<PreparedPhoto>.unmodifiable(photos);
  final String id;
  final String operationId;
  final String draftId;
  final int revision;
  final String caption;
  final bool ownCaption;
  final List<PreparedPhoto> photos;
  final DateTime createdAt;
  factory InstagramPackage.fromJson(Map<String, dynamic> json) =>
      _$InstagramPackageFromJson(json);
  Map<String, dynamic> toJson() => _$InstagramPackageToJson(this);
}

@freezed
abstract class InstagramEvent with _$InstagramEvent {
  const factory InstagramEvent({
    required String id,
    required InstagramEventKind kind,
    required DateTime at,
    int? photoOrdinal,
    String? uri,
    String? launchId,
    String? targetPackage,
  }) = _InstagramEvent;
  factory InstagramEvent.fromJson(Map<String, dynamic> json) =>
      _$InstagramEventFromJson(json);
}

@freezed
@JsonSerializable()
class InstagramProgress with _$InstagramProgress {
  InstagramProgress({
    required this.state,
    this.priorPending,
    this.confirmedAt,
    this.activeLaunchId,
    this.promptedLaunchId,
    Map<int, String> savedUris = const {},
  }) : savedUris = Map<int, String>.unmodifiable(savedUris);
  final InstagramState state;
  final InstagramState? priorPending;
  final DateTime? confirmedAt;
  final String? activeLaunchId;
  final String? promptedLaunchId;
  final Map<int, String> savedUris;
  factory InstagramProgress.fromJson(Map<String, dynamic> json) =>
      _$InstagramProgressFromJson(json);
  Map<String, dynamic> toJson() => _$InstagramProgressToJson(this);
}
