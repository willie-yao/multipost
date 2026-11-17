// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'instagram_package.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PreparedPhoto {

 String get assetId; String get relativePath; String get sha256; int get ordinal; String get altText;
/// Create a copy of PreparedPhoto
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PreparedPhotoCopyWith<PreparedPhoto> get copyWith => _$PreparedPhotoCopyWithImpl<PreparedPhoto>(this as PreparedPhoto, _$identity);

  /// Serializes this PreparedPhoto to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PreparedPhoto;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PreparedPhoto&&(identical(other.assetId, _this.assetId) || other.assetId == _this.assetId)&&(identical(other.relativePath, _this.relativePath) || other.relativePath == _this.relativePath)&&(identical(other.sha256, _this.sha256) || other.sha256 == _this.sha256)&&(identical(other.ordinal, _this.ordinal) || other.ordinal == _this.ordinal)&&(identical(other.altText, _this.altText) || other.altText == _this.altText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PreparedPhoto;
  return Object.hash(runtimeType,_this.assetId,_this.relativePath,_this.sha256,_this.ordinal,_this.altText);
}

@override
String toString() {
  final _this = this as PreparedPhoto;
  return 'PreparedPhoto(assetId: ${_this.assetId}, relativePath: ${_this.relativePath}, sha256: ${_this.sha256}, ordinal: ${_this.ordinal}, altText: ${_this.altText})';
}


}

/// @nodoc
abstract mixin class $PreparedPhotoCopyWith<$Res>  {
  factory $PreparedPhotoCopyWith(PreparedPhoto value, $Res Function(PreparedPhoto) _then) = _$PreparedPhotoCopyWithImpl;
@useResult
$Res call({
 String assetId, String relativePath, String sha256, int ordinal, String altText
});




}
/// @nodoc
class _$PreparedPhotoCopyWithImpl<$Res>
    implements $PreparedPhotoCopyWith<$Res> {
  _$PreparedPhotoCopyWithImpl(this._self, this._then);

  final PreparedPhoto _self;
  final $Res Function(PreparedPhoto) _then;

/// Create a copy of PreparedPhoto
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assetId = null,Object? relativePath = null,Object? sha256 = null,Object? ordinal = null,Object? altText = null,}) {
  return _then(PreparedPhoto(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,ordinal: null == ordinal ? _self.ordinal : ordinal // ignore: cast_nullable_to_non_nullable
as int,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PreparedPhoto].
extension PreparedPhotoPatterns on PreparedPhoto {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PreparedPhoto value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PreparedPhoto() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PreparedPhoto value)  $default,){
final _that = this;
switch (_that) {
case _PreparedPhoto():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PreparedPhoto value)?  $default,){
final _that = this;
switch (_that) {
case _PreparedPhoto() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String assetId,  String relativePath,  String sha256,  int ordinal,  String altText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PreparedPhoto() when $default != null:
return $default(_that.assetId,_that.relativePath,_that.sha256,_that.ordinal,_that.altText);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String assetId,  String relativePath,  String sha256,  int ordinal,  String altText)  $default,) {final _that = this;
switch (_that) {
case _PreparedPhoto():
return $default(_that.assetId,_that.relativePath,_that.sha256,_that.ordinal,_that.altText);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String assetId,  String relativePath,  String sha256,  int ordinal,  String altText)?  $default,) {final _that = this;
switch (_that) {
case _PreparedPhoto() when $default != null:
return $default(_that.assetId,_that.relativePath,_that.sha256,_that.ordinal,_that.altText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PreparedPhoto implements PreparedPhoto {
  const _PreparedPhoto({required this.assetId, required this.relativePath, required this.sha256, required this.ordinal, required this.altText});
  factory _PreparedPhoto.fromJson(Map<String, dynamic> json) => _$PreparedPhotoFromJson(json);

@override final  String assetId;
@override final  String relativePath;
@override final  String sha256;
@override final  int ordinal;
@override final  String altText;

/// Create a copy of PreparedPhoto
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreparedPhotoCopyWith<_PreparedPhoto> get copyWith => __$PreparedPhotoCopyWithImpl<_PreparedPhoto>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PreparedPhotoToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PreparedPhoto&&(identical(other.assetId, assetId) || other.assetId == assetId)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.ordinal, ordinal) || other.ordinal == ordinal)&&(identical(other.altText, altText) || other.altText == altText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,assetId,relativePath,sha256,ordinal,altText);
}

@override
String toString() {
    return 'PreparedPhoto(assetId: $assetId, relativePath: $relativePath, sha256: $sha256, ordinal: $ordinal, altText: $altText)';
}


}

/// @nodoc
abstract mixin class _$PreparedPhotoCopyWith<$Res> implements $PreparedPhotoCopyWith<$Res> {
  factory _$PreparedPhotoCopyWith(_PreparedPhoto value, $Res Function(_PreparedPhoto) _then) = __$PreparedPhotoCopyWithImpl;
@override @useResult
$Res call({
 String assetId, String relativePath, String sha256, int ordinal, String altText
});




}
/// @nodoc
class __$PreparedPhotoCopyWithImpl<$Res>
    implements _$PreparedPhotoCopyWith<$Res> {
  __$PreparedPhotoCopyWithImpl(this._self, this._then);

  final _PreparedPhoto _self;
  final $Res Function(_PreparedPhoto) _then;

/// Create a copy of PreparedPhoto
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assetId = null,Object? relativePath = null,Object? sha256 = null,Object? ordinal = null,Object? altText = null,}) {
  return _then(_PreparedPhoto(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,ordinal: null == ordinal ? _self.ordinal : ordinal // ignore: cast_nullable_to_non_nullable
as int,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$InstagramPackage {


/// Create a copy of InstagramPackage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstagramPackageCopyWith<InstagramPackage> get copyWith => _$InstagramPackageCopyWithImpl<InstagramPackage>(this as InstagramPackage, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstagramPackage;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstagramPackage&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.operationId, _this.operationId) || other.operationId == _this.operationId)&&(identical(other.draftId, _this.draftId) || other.draftId == _this.draftId)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.caption, _this.caption) || other.caption == _this.caption)&&(identical(other.ownCaption, _this.ownCaption) || other.ownCaption == _this.ownCaption)&&const DeepCollectionEquality().equals(other.photos, _this.photos)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InstagramPackage;
  return Object.hash(runtimeType,_this.id,_this.operationId,_this.draftId,_this.revision,_this.caption,_this.ownCaption,const DeepCollectionEquality().hash(_this.photos),_this.createdAt);
}

@override
String toString() {
  final _this = this as InstagramPackage;
  return 'InstagramPackage(id: ${_this.id}, operationId: ${_this.operationId}, draftId: ${_this.draftId}, revision: ${_this.revision}, caption: ${_this.caption}, ownCaption: ${_this.ownCaption}, photos: ${_this.photos}, createdAt: ${_this.createdAt})';
}


}

/// @nodoc
abstract mixin class $InstagramPackageCopyWith<$Res>  {
  factory $InstagramPackageCopyWith(InstagramPackage value, $Res Function(InstagramPackage) _then) = _$InstagramPackageCopyWithImpl;
@useResult
$Res call({
 String id, String operationId, String draftId, int revision, String caption, bool ownCaption, List<PreparedPhoto> photos, DateTime createdAt
});




}
/// @nodoc
class _$InstagramPackageCopyWithImpl<$Res>
    implements $InstagramPackageCopyWith<$Res> {
  _$InstagramPackageCopyWithImpl(this._self, this._then);

  final InstagramPackage _self;
  final $Res Function(InstagramPackage) _then;

/// Create a copy of InstagramPackage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? operationId = null,Object? draftId = null,Object? revision = null,Object? caption = null,Object? ownCaption = null,Object? photos = null,Object? createdAt = null,}) {
  return _then(InstagramPackage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,operationId: null == operationId ? _self.operationId : operationId // ignore: cast_nullable_to_non_nullable
as String,draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,caption: null == caption ? _self.caption : caption // ignore: cast_nullable_to_non_nullable
as String,ownCaption: null == ownCaption ? _self.ownCaption : ownCaption // ignore: cast_nullable_to_non_nullable
as bool,photos: null == photos ? _self.photos : photos // ignore: cast_nullable_to_non_nullable
as List<PreparedPhoto>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [InstagramPackage].
extension InstagramPackagePatterns on InstagramPackage {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}


/// @nodoc
mixin _$InstagramEvent {

 String get id; InstagramEventKind get kind; DateTime get at; int? get photoOrdinal; String? get uri; String? get launchId; String? get targetPackage;
/// Create a copy of InstagramEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstagramEventCopyWith<InstagramEvent> get copyWith => _$InstagramEventCopyWithImpl<InstagramEvent>(this as InstagramEvent, _$identity);

  /// Serializes this InstagramEvent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as InstagramEvent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstagramEvent&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.at, _this.at) || other.at == _this.at)&&(identical(other.photoOrdinal, _this.photoOrdinal) || other.photoOrdinal == _this.photoOrdinal)&&(identical(other.uri, _this.uri) || other.uri == _this.uri)&&(identical(other.launchId, _this.launchId) || other.launchId == _this.launchId)&&(identical(other.targetPackage, _this.targetPackage) || other.targetPackage == _this.targetPackage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InstagramEvent;
  return Object.hash(runtimeType,_this.id,_this.kind,_this.at,_this.photoOrdinal,_this.uri,_this.launchId,_this.targetPackage);
}

@override
String toString() {
  final _this = this as InstagramEvent;
  return 'InstagramEvent(id: ${_this.id}, kind: ${_this.kind}, at: ${_this.at}, photoOrdinal: ${_this.photoOrdinal}, uri: ${_this.uri}, launchId: ${_this.launchId}, targetPackage: ${_this.targetPackage})';
}


}

/// @nodoc
abstract mixin class $InstagramEventCopyWith<$Res>  {
  factory $InstagramEventCopyWith(InstagramEvent value, $Res Function(InstagramEvent) _then) = _$InstagramEventCopyWithImpl;
@useResult
$Res call({
 String id, InstagramEventKind kind, DateTime at, int? photoOrdinal, String? uri, String? launchId, String? targetPackage
});




}
/// @nodoc
class _$InstagramEventCopyWithImpl<$Res>
    implements $InstagramEventCopyWith<$Res> {
  _$InstagramEventCopyWithImpl(this._self, this._then);

  final InstagramEvent _self;
  final $Res Function(InstagramEvent) _then;

/// Create a copy of InstagramEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? at = null,Object? photoOrdinal = freezed,Object? uri = freezed,Object? launchId = freezed,Object? targetPackage = freezed,}) {
  return _then(InstagramEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InstagramEventKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,photoOrdinal: freezed == photoOrdinal ? _self.photoOrdinal : photoOrdinal // ignore: cast_nullable_to_non_nullable
as int?,uri: freezed == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String?,launchId: freezed == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String?,targetPackage: freezed == targetPackage ? _self.targetPackage : targetPackage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [InstagramEvent].
extension InstagramEventPatterns on InstagramEvent {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _InstagramEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _InstagramEvent() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _InstagramEvent value)  $default,){
final _that = this;
switch (_that) {
case _InstagramEvent():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _InstagramEvent value)?  $default,){
final _that = this;
switch (_that) {
case _InstagramEvent() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  InstagramEventKind kind,  DateTime at,  int? photoOrdinal,  String? uri,  String? launchId,  String? targetPackage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _InstagramEvent() when $default != null:
return $default(_that.id,_that.kind,_that.at,_that.photoOrdinal,_that.uri,_that.launchId,_that.targetPackage);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  InstagramEventKind kind,  DateTime at,  int? photoOrdinal,  String? uri,  String? launchId,  String? targetPackage)  $default,) {final _that = this;
switch (_that) {
case _InstagramEvent():
return $default(_that.id,_that.kind,_that.at,_that.photoOrdinal,_that.uri,_that.launchId,_that.targetPackage);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  InstagramEventKind kind,  DateTime at,  int? photoOrdinal,  String? uri,  String? launchId,  String? targetPackage)?  $default,) {final _that = this;
switch (_that) {
case _InstagramEvent() when $default != null:
return $default(_that.id,_that.kind,_that.at,_that.photoOrdinal,_that.uri,_that.launchId,_that.targetPackage);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _InstagramEvent implements InstagramEvent {
  const _InstagramEvent({required this.id, required this.kind, required this.at, this.photoOrdinal, this.uri, this.launchId, this.targetPackage});
  factory _InstagramEvent.fromJson(Map<String, dynamic> json) => _$InstagramEventFromJson(json);

@override final  String id;
@override final  InstagramEventKind kind;
@override final  DateTime at;
@override final  int? photoOrdinal;
@override final  String? uri;
@override final  String? launchId;
@override final  String? targetPackage;

/// Create a copy of InstagramEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$InstagramEventCopyWith<_InstagramEvent> get copyWith => __$InstagramEventCopyWithImpl<_InstagramEvent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$InstagramEventToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _InstagramEvent&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.at, at) || other.at == at)&&(identical(other.photoOrdinal, photoOrdinal) || other.photoOrdinal == photoOrdinal)&&(identical(other.uri, uri) || other.uri == uri)&&(identical(other.launchId, launchId) || other.launchId == launchId)&&(identical(other.targetPackage, targetPackage) || other.targetPackage == targetPackage));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,at,photoOrdinal,uri,launchId,targetPackage);
}

@override
String toString() {
    return 'InstagramEvent(id: $id, kind: $kind, at: $at, photoOrdinal: $photoOrdinal, uri: $uri, launchId: $launchId, targetPackage: $targetPackage)';
}


}

/// @nodoc
abstract mixin class _$InstagramEventCopyWith<$Res> implements $InstagramEventCopyWith<$Res> {
  factory _$InstagramEventCopyWith(_InstagramEvent value, $Res Function(_InstagramEvent) _then) = __$InstagramEventCopyWithImpl;
@override @useResult
$Res call({
 String id, InstagramEventKind kind, DateTime at, int? photoOrdinal, String? uri, String? launchId, String? targetPackage
});




}
/// @nodoc
class __$InstagramEventCopyWithImpl<$Res>
    implements _$InstagramEventCopyWith<$Res> {
  __$InstagramEventCopyWithImpl(this._self, this._then);

  final _InstagramEvent _self;
  final $Res Function(_InstagramEvent) _then;

/// Create a copy of InstagramEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? at = null,Object? photoOrdinal = freezed,Object? uri = freezed,Object? launchId = freezed,Object? targetPackage = freezed,}) {
  return _then(_InstagramEvent(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as InstagramEventKind,at: null == at ? _self.at : at // ignore: cast_nullable_to_non_nullable
as DateTime,photoOrdinal: freezed == photoOrdinal ? _self.photoOrdinal : photoOrdinal // ignore: cast_nullable_to_non_nullable
as int?,uri: freezed == uri ? _self.uri : uri // ignore: cast_nullable_to_non_nullable
as String?,launchId: freezed == launchId ? _self.launchId : launchId // ignore: cast_nullable_to_non_nullable
as String?,targetPackage: freezed == targetPackage ? _self.targetPackage : targetPackage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$InstagramProgress {


/// Create a copy of InstagramProgress
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$InstagramProgressCopyWith<InstagramProgress> get copyWith => _$InstagramProgressCopyWithImpl<InstagramProgress>(this as InstagramProgress, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as InstagramProgress;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is InstagramProgress&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.priorPending, _this.priorPending) || other.priorPending == _this.priorPending)&&(identical(other.confirmedAt, _this.confirmedAt) || other.confirmedAt == _this.confirmedAt)&&(identical(other.activeLaunchId, _this.activeLaunchId) || other.activeLaunchId == _this.activeLaunchId)&&(identical(other.promptedLaunchId, _this.promptedLaunchId) || other.promptedLaunchId == _this.promptedLaunchId)&&const DeepCollectionEquality().equals(other.savedUris, _this.savedUris));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as InstagramProgress;
  return Object.hash(runtimeType,_this.state,_this.priorPending,_this.confirmedAt,_this.activeLaunchId,_this.promptedLaunchId,const DeepCollectionEquality().hash(_this.savedUris));
}

@override
String toString() {
  final _this = this as InstagramProgress;
  return 'InstagramProgress(state: ${_this.state}, priorPending: ${_this.priorPending}, confirmedAt: ${_this.confirmedAt}, activeLaunchId: ${_this.activeLaunchId}, promptedLaunchId: ${_this.promptedLaunchId}, savedUris: ${_this.savedUris})';
}


}

/// @nodoc
abstract mixin class $InstagramProgressCopyWith<$Res>  {
  factory $InstagramProgressCopyWith(InstagramProgress value, $Res Function(InstagramProgress) _then) = _$InstagramProgressCopyWithImpl;
@useResult
$Res call({
 InstagramState state, InstagramState? priorPending, DateTime? confirmedAt, String? activeLaunchId, String? promptedLaunchId, Map<int, String> savedUris
});




}
/// @nodoc
class _$InstagramProgressCopyWithImpl<$Res>
    implements $InstagramProgressCopyWith<$Res> {
  _$InstagramProgressCopyWithImpl(this._self, this._then);

  final InstagramProgress _self;
  final $Res Function(InstagramProgress) _then;

/// Create a copy of InstagramProgress
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,Object? priorPending = freezed,Object? confirmedAt = freezed,Object? activeLaunchId = freezed,Object? promptedLaunchId = freezed,Object? savedUris = null,}) {
  return _then(InstagramProgress(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as InstagramState,priorPending: freezed == priorPending ? _self.priorPending : priorPending // ignore: cast_nullable_to_non_nullable
as InstagramState?,confirmedAt: freezed == confirmedAt ? _self.confirmedAt : confirmedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,activeLaunchId: freezed == activeLaunchId ? _self.activeLaunchId : activeLaunchId // ignore: cast_nullable_to_non_nullable
as String?,promptedLaunchId: freezed == promptedLaunchId ? _self.promptedLaunchId : promptedLaunchId // ignore: cast_nullable_to_non_nullable
as String?,savedUris: null == savedUris ? _self.savedUris : savedUris // ignore: cast_nullable_to_non_nullable
as Map<int, String>,
  ));
}

}


/// Adds pattern-matching-related methods to [InstagramProgress].
extension InstagramProgressPatterns on InstagramProgress {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({required TResult orElse(),}){
final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(){
final _that = this;
switch (_that) {
case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({required TResult orElse(),}) {final _that = this;
switch (_that) {
case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>() {final _that = this;
switch (_that) {
case _:
  return null;

}
}

}

// dart format on
