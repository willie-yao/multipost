// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'draft.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Attachment {

 String get assetId; String get altText;
/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentCopyWith<Attachment> get copyWith => _$AttachmentCopyWithImpl<Attachment>(this as Attachment, _$identity);

  /// Serializes this Attachment to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Attachment;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Attachment&&(identical(other.assetId, _this.assetId) || other.assetId == _this.assetId)&&(identical(other.altText, _this.altText) || other.altText == _this.altText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Attachment;
  return Object.hash(runtimeType,_this.assetId,_this.altText);
}

@override
String toString() {
  final _this = this as Attachment;
  return 'Attachment(assetId: ${_this.assetId}, altText: ${_this.altText})';
}


}

/// @nodoc
abstract mixin class $AttachmentCopyWith<$Res>  {
  factory $AttachmentCopyWith(Attachment value, $Res Function(Attachment) _then) = _$AttachmentCopyWithImpl;
@useResult
$Res call({
 String assetId, String altText
});




}
/// @nodoc
class _$AttachmentCopyWithImpl<$Res>
    implements $AttachmentCopyWith<$Res> {
  _$AttachmentCopyWithImpl(this._self, this._then);

  final Attachment _self;
  final $Res Function(Attachment) _then;

/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? assetId = null,Object? altText = null,}) {
  return _then(Attachment(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Attachment].
extension AttachmentPatterns on Attachment {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Attachment value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Attachment() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Attachment value)  $default,){
final _that = this;
switch (_that) {
case _Attachment():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Attachment value)?  $default,){
final _that = this;
switch (_that) {
case _Attachment() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String assetId,  String altText)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Attachment() when $default != null:
return $default(_that.assetId,_that.altText);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String assetId,  String altText)  $default,) {final _that = this;
switch (_that) {
case _Attachment():
return $default(_that.assetId,_that.altText);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String assetId,  String altText)?  $default,) {final _that = this;
switch (_that) {
case _Attachment() when $default != null:
return $default(_that.assetId,_that.altText);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Attachment implements Attachment {
  const _Attachment({required this.assetId, this.altText = ''});
  factory _Attachment.fromJson(Map<String, dynamic> json) => _$AttachmentFromJson(json);

@override final  String assetId;
@override@JsonKey() final  String altText;

/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentCopyWith<_Attachment> get copyWith => __$AttachmentCopyWithImpl<_Attachment>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttachmentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Attachment&&(identical(other.assetId, assetId) || other.assetId == assetId)&&(identical(other.altText, altText) || other.altText == altText));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,assetId,altText);
}

@override
String toString() {
    return 'Attachment(assetId: $assetId, altText: $altText)';
}


}

/// @nodoc
abstract mixin class _$AttachmentCopyWith<$Res> implements $AttachmentCopyWith<$Res> {
  factory _$AttachmentCopyWith(_Attachment value, $Res Function(_Attachment) _then) = __$AttachmentCopyWithImpl;
@override @useResult
$Res call({
 String assetId, String altText
});




}
/// @nodoc
class __$AttachmentCopyWithImpl<$Res>
    implements _$AttachmentCopyWith<$Res> {
  __$AttachmentCopyWithImpl(this._self, this._then);

  final _Attachment _self;
  final $Res Function(_Attachment) _then;

/// Create a copy of Attachment
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? assetId = null,Object? altText = null,}) {
  return _then(_Attachment(
assetId: null == assetId ? _self.assetId : assetId // ignore: cast_nullable_to_non_nullable
as String,altText: null == altText ? _self.altText : altText // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PostContent {

 String get text; List<Attachment> get media;
/// Create a copy of PostContent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PostContentCopyWith<PostContent> get copyWith => _$PostContentCopyWithImpl<PostContent>(this as PostContent, _$identity);

  /// Serializes this PostContent to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PostContent;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PostContent&&(identical(other.text, _this.text) || other.text == _this.text)&&const DeepCollectionEquality().equals(other.media, _this.media));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PostContent;
  return Object.hash(runtimeType,_this.text,const DeepCollectionEquality().hash(_this.media));
}

@override
String toString() {
  final _this = this as PostContent;
  return 'PostContent(text: ${_this.text}, media: ${_this.media})';
}


}

/// @nodoc
abstract mixin class $PostContentCopyWith<$Res>  {
  factory $PostContentCopyWith(PostContent value, $Res Function(PostContent) _then) = _$PostContentCopyWithImpl;
@useResult
$Res call({
 String text, List<Attachment> media
});




}
/// @nodoc
class _$PostContentCopyWithImpl<$Res>
    implements $PostContentCopyWith<$Res> {
  _$PostContentCopyWithImpl(this._self, this._then);

  final PostContent _self;
  final $Res Function(PostContent) _then;

/// Create a copy of PostContent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? text = null,Object? media = null,}) {
  return _then(PostContent(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as List<Attachment>,
  ));
}

}


/// Adds pattern-matching-related methods to [PostContent].
extension PostContentPatterns on PostContent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PostContent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PostContent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PostContent value)  $default,){
final _that = this;
switch (_that) {
case _PostContent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PostContent value)?  $default,){
final _that = this;
switch (_that) {
case _PostContent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String text,  List<Attachment> media)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PostContent() when $default != null:
return $default(_that.text,_that.media);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String text,  List<Attachment> media)  $default,) {final _that = this;
switch (_that) {
case _PostContent():
return $default(_that.text,_that.media);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String text,  List<Attachment> media)?  $default,) {final _that = this;
switch (_that) {
case _PostContent() when $default != null:
return $default(_that.text,_that.media);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PostContent implements PostContent {
  const _PostContent({this.text = '',  List<Attachment> media = const []}): _media = media;
  factory _PostContent.fromJson(Map<String, dynamic> json) => _$PostContentFromJson(json);

@override@JsonKey() final  String text;
 final  List<Attachment> _media;
@override@JsonKey() List<Attachment> get media {
  if (_media is EqualUnmodifiableListView) return _media;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_media);
}


/// Create a copy of PostContent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PostContentCopyWith<_PostContent> get copyWith => __$PostContentCopyWithImpl<_PostContent>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PostContentToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PostContent&&(identical(other.text, text) || other.text == text)&&const DeepCollectionEquality().equals(other.media, _media));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,text,const DeepCollectionEquality().hash(_media));
}

@override
String toString() {
    return 'PostContent(text: $text, media: $media)';
}


}

/// @nodoc
abstract mixin class _$PostContentCopyWith<$Res> implements $PostContentCopyWith<$Res> {
  factory _$PostContentCopyWith(_PostContent value, $Res Function(_PostContent) _then) = __$PostContentCopyWithImpl;
@override @useResult
$Res call({
 String text, List<Attachment> media
});




}
/// @nodoc
class __$PostContentCopyWithImpl<$Res>
    implements _$PostContentCopyWith<$Res> {
  __$PostContentCopyWithImpl(this._self, this._then);

  final _PostContent _self;
  final $Res Function(_PostContent) _then;

/// Create a copy of PostContent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? text = null,Object? media = null,}) {
  return _then(_PostContent(
text: null == text ? _self.text : text // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self._media : media // ignore: cast_nullable_to_non_nullable
as List<Attachment>,
  ));
}


}


/// @nodoc
mixin _$DestinationVersion {

 String? get ownText; List<Attachment>? get ownMedia; int? get baseTextRevision; int? get baseMediaRevision;
/// Create a copy of DestinationVersion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DestinationVersionCopyWith<DestinationVersion> get copyWith => _$DestinationVersionCopyWithImpl<DestinationVersion>(this as DestinationVersion, _$identity);

  /// Serializes this DestinationVersion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DestinationVersion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DestinationVersion&&(identical(other.ownText, _this.ownText) || other.ownText == _this.ownText)&&const DeepCollectionEquality().equals(other.ownMedia, _this.ownMedia)&&(identical(other.baseTextRevision, _this.baseTextRevision) || other.baseTextRevision == _this.baseTextRevision)&&(identical(other.baseMediaRevision, _this.baseMediaRevision) || other.baseMediaRevision == _this.baseMediaRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DestinationVersion;
  return Object.hash(runtimeType,_this.ownText,const DeepCollectionEquality().hash(_this.ownMedia),_this.baseTextRevision,_this.baseMediaRevision);
}

@override
String toString() {
  final _this = this as DestinationVersion;
  return 'DestinationVersion(ownText: ${_this.ownText}, ownMedia: ${_this.ownMedia}, baseTextRevision: ${_this.baseTextRevision}, baseMediaRevision: ${_this.baseMediaRevision})';
}


}

/// @nodoc
abstract mixin class $DestinationVersionCopyWith<$Res>  {
  factory $DestinationVersionCopyWith(DestinationVersion value, $Res Function(DestinationVersion) _then) = _$DestinationVersionCopyWithImpl;
@useResult
$Res call({
 String? ownText, List<Attachment>? ownMedia, int? baseTextRevision, int? baseMediaRevision
});




}
/// @nodoc
class _$DestinationVersionCopyWithImpl<$Res>
    implements $DestinationVersionCopyWith<$Res> {
  _$DestinationVersionCopyWithImpl(this._self, this._then);

  final DestinationVersion _self;
  final $Res Function(DestinationVersion) _then;

/// Create a copy of DestinationVersion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ownText = freezed,Object? ownMedia = freezed,Object? baseTextRevision = freezed,Object? baseMediaRevision = freezed,}) {
  return _then(DestinationVersion(
ownText: freezed == ownText ? _self.ownText : ownText // ignore: cast_nullable_to_non_nullable
as String?,ownMedia: freezed == ownMedia ? _self.ownMedia : ownMedia // ignore: cast_nullable_to_non_nullable
as List<Attachment>?,baseTextRevision: freezed == baseTextRevision ? _self.baseTextRevision : baseTextRevision // ignore: cast_nullable_to_non_nullable
as int?,baseMediaRevision: freezed == baseMediaRevision ? _self.baseMediaRevision : baseMediaRevision // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [DestinationVersion].
extension DestinationVersionPatterns on DestinationVersion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DestinationVersion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DestinationVersion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DestinationVersion value)  $default,){
final _that = this;
switch (_that) {
case _DestinationVersion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DestinationVersion value)?  $default,){
final _that = this;
switch (_that) {
case _DestinationVersion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? ownText,  List<Attachment>? ownMedia,  int? baseTextRevision,  int? baseMediaRevision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DestinationVersion() when $default != null:
return $default(_that.ownText,_that.ownMedia,_that.baseTextRevision,_that.baseMediaRevision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? ownText,  List<Attachment>? ownMedia,  int? baseTextRevision,  int? baseMediaRevision)  $default,) {final _that = this;
switch (_that) {
case _DestinationVersion():
return $default(_that.ownText,_that.ownMedia,_that.baseTextRevision,_that.baseMediaRevision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? ownText,  List<Attachment>? ownMedia,  int? baseTextRevision,  int? baseMediaRevision)?  $default,) {final _that = this;
switch (_that) {
case _DestinationVersion() when $default != null:
return $default(_that.ownText,_that.ownMedia,_that.baseTextRevision,_that.baseMediaRevision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DestinationVersion implements DestinationVersion {
  const _DestinationVersion({this.ownText,  List<Attachment>? ownMedia, this.baseTextRevision, this.baseMediaRevision}): _ownMedia = ownMedia;
  factory _DestinationVersion.fromJson(Map<String, dynamic> json) => _$DestinationVersionFromJson(json);

@override final  String? ownText;
 final  List<Attachment>? _ownMedia;
@override List<Attachment>? get ownMedia {
  final value = _ownMedia;
  if (value == null) return null;
  if (_ownMedia is EqualUnmodifiableListView) return _ownMedia;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  int? baseTextRevision;
@override final  int? baseMediaRevision;

/// Create a copy of DestinationVersion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DestinationVersionCopyWith<_DestinationVersion> get copyWith => __$DestinationVersionCopyWithImpl<_DestinationVersion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DestinationVersionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DestinationVersion&&(identical(other.ownText, ownText) || other.ownText == ownText)&&const DeepCollectionEquality().equals(other.ownMedia, _ownMedia)&&(identical(other.baseTextRevision, baseTextRevision) || other.baseTextRevision == baseTextRevision)&&(identical(other.baseMediaRevision, baseMediaRevision) || other.baseMediaRevision == baseMediaRevision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,ownText,const DeepCollectionEquality().hash(_ownMedia),baseTextRevision,baseMediaRevision);
}

@override
String toString() {
    return 'DestinationVersion(ownText: $ownText, ownMedia: $ownMedia, baseTextRevision: $baseTextRevision, baseMediaRevision: $baseMediaRevision)';
}


}

/// @nodoc
abstract mixin class _$DestinationVersionCopyWith<$Res> implements $DestinationVersionCopyWith<$Res> {
  factory _$DestinationVersionCopyWith(_DestinationVersion value, $Res Function(_DestinationVersion) _then) = __$DestinationVersionCopyWithImpl;
@override @useResult
$Res call({
 String? ownText, List<Attachment>? ownMedia, int? baseTextRevision, int? baseMediaRevision
});




}
/// @nodoc
class __$DestinationVersionCopyWithImpl<$Res>
    implements _$DestinationVersionCopyWith<$Res> {
  __$DestinationVersionCopyWithImpl(this._self, this._then);

  final _DestinationVersion _self;
  final $Res Function(_DestinationVersion) _then;

/// Create a copy of DestinationVersion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ownText = freezed,Object? ownMedia = freezed,Object? baseTextRevision = freezed,Object? baseMediaRevision = freezed,}) {
  return _then(_DestinationVersion(
ownText: freezed == ownText ? _self.ownText : ownText // ignore: cast_nullable_to_non_nullable
as String?,ownMedia: freezed == ownMedia ? _self._ownMedia : ownMedia // ignore: cast_nullable_to_non_nullable
as List<Attachment>?,baseTextRevision: freezed == baseTextRevision ? _self.baseTextRevision : baseTextRevision // ignore: cast_nullable_to_non_nullable
as int?,baseMediaRevision: freezed == baseMediaRevision ? _self.baseMediaRevision : baseMediaRevision // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}


/// @nodoc
mixin _$Draft {

 String get id; DateTime get updatedAt; int get revision; int get sharedTextRevision; int get sharedMediaRevision; ComposeStage get stage; Set<Destination> get selected; PostContent get shared; Map<Destination, DestinationVersion> get versions; DateTime? get deletedAt;
/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DraftCopyWith<Draft> get copyWith => _$DraftCopyWithImpl<Draft>(this as Draft, _$identity);

  /// Serializes this Draft to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Draft;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Draft&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.sharedTextRevision, _this.sharedTextRevision) || other.sharedTextRevision == _this.sharedTextRevision)&&(identical(other.sharedMediaRevision, _this.sharedMediaRevision) || other.sharedMediaRevision == _this.sharedMediaRevision)&&(identical(other.stage, _this.stage) || other.stage == _this.stage)&&const DeepCollectionEquality().equals(other.selected, _this.selected)&&(identical(other.shared, _this.shared) || other.shared == _this.shared)&&const DeepCollectionEquality().equals(other.versions, _this.versions)&&(identical(other.deletedAt, _this.deletedAt) || other.deletedAt == _this.deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Draft;
  return Object.hash(runtimeType,_this.id,_this.updatedAt,_this.revision,_this.sharedTextRevision,_this.sharedMediaRevision,_this.stage,const DeepCollectionEquality().hash(_this.selected),_this.shared,const DeepCollectionEquality().hash(_this.versions),_this.deletedAt);
}

@override
String toString() {
  final _this = this as Draft;
  return 'Draft(id: ${_this.id}, updatedAt: ${_this.updatedAt}, revision: ${_this.revision}, sharedTextRevision: ${_this.sharedTextRevision}, sharedMediaRevision: ${_this.sharedMediaRevision}, stage: ${_this.stage}, selected: ${_this.selected}, shared: ${_this.shared}, versions: ${_this.versions}, deletedAt: ${_this.deletedAt})';
}


}

/// @nodoc
abstract mixin class $DraftCopyWith<$Res>  {
  factory $DraftCopyWith(Draft value, $Res Function(Draft) _then) = _$DraftCopyWithImpl;
@useResult
$Res call({
 String id, DateTime updatedAt, int revision, int sharedTextRevision, int sharedMediaRevision, ComposeStage stage, Set<Destination> selected, PostContent shared, Map<Destination, DestinationVersion> versions, DateTime? deletedAt
});


$PostContentCopyWith<$Res> get shared;

}
/// @nodoc
class _$DraftCopyWithImpl<$Res>
    implements $DraftCopyWith<$Res> {
  _$DraftCopyWithImpl(this._self, this._then);

  final Draft _self;
  final $Res Function(Draft) _then;

/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? updatedAt = null,Object? revision = null,Object? sharedTextRevision = null,Object? sharedMediaRevision = null,Object? stage = null,Object? selected = null,Object? shared = null,Object? versions = null,Object? deletedAt = freezed,}) {
  return _then(Draft(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,sharedTextRevision: null == sharedTextRevision ? _self.sharedTextRevision : sharedTextRevision // ignore: cast_nullable_to_non_nullable
as int,sharedMediaRevision: null == sharedMediaRevision ? _self.sharedMediaRevision : sharedMediaRevision // ignore: cast_nullable_to_non_nullable
as int,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as ComposeStage,selected: null == selected ? _self.selected : selected // ignore: cast_nullable_to_non_nullable
as Set<Destination>,shared: null == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as PostContent,versions: null == versions ? _self.versions : versions // ignore: cast_nullable_to_non_nullable
as Map<Destination, DestinationVersion>,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostContentCopyWith<$Res> get shared {
  
  return $PostContentCopyWith<$Res>(_self.shared, (value) {
    return _then(_self.copyWith(shared: value));
  });
}
}


/// Adds pattern-matching-related methods to [Draft].
extension DraftPatterns on Draft {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Draft value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Draft() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Draft value)  $default,){
final _that = this;
switch (_that) {
case _Draft():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Draft value)?  $default,){
final _that = this;
switch (_that) {
case _Draft() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  DateTime updatedAt,  int revision,  int sharedTextRevision,  int sharedMediaRevision,  ComposeStage stage,  Set<Destination> selected,  PostContent shared,  Map<Destination, DestinationVersion> versions,  DateTime? deletedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Draft() when $default != null:
return $default(_that.id,_that.updatedAt,_that.revision,_that.sharedTextRevision,_that.sharedMediaRevision,_that.stage,_that.selected,_that.shared,_that.versions,_that.deletedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  DateTime updatedAt,  int revision,  int sharedTextRevision,  int sharedMediaRevision,  ComposeStage stage,  Set<Destination> selected,  PostContent shared,  Map<Destination, DestinationVersion> versions,  DateTime? deletedAt)  $default,) {final _that = this;
switch (_that) {
case _Draft():
return $default(_that.id,_that.updatedAt,_that.revision,_that.sharedTextRevision,_that.sharedMediaRevision,_that.stage,_that.selected,_that.shared,_that.versions,_that.deletedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  DateTime updatedAt,  int revision,  int sharedTextRevision,  int sharedMediaRevision,  ComposeStage stage,  Set<Destination> selected,  PostContent shared,  Map<Destination, DestinationVersion> versions,  DateTime? deletedAt)?  $default,) {final _that = this;
switch (_that) {
case _Draft() when $default != null:
return $default(_that.id,_that.updatedAt,_that.revision,_that.sharedTextRevision,_that.sharedMediaRevision,_that.stage,_that.selected,_that.shared,_that.versions,_that.deletedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Draft implements Draft {
  const _Draft({required this.id, required this.updatedAt, this.revision = 0, this.sharedTextRevision = 0, this.sharedMediaRevision = 0, this.stage = ComposeStage.choose,  Set<Destination> selected = const {}, this.shared = const PostContent(),  Map<Destination, DestinationVersion> versions = const {}, this.deletedAt}): _selected = selected,_versions = versions;
  factory _Draft.fromJson(Map<String, dynamic> json) => _$DraftFromJson(json);

@override final  String id;
@override final  DateTime updatedAt;
@override@JsonKey() final  int revision;
@override@JsonKey() final  int sharedTextRevision;
@override@JsonKey() final  int sharedMediaRevision;
@override@JsonKey() final  ComposeStage stage;
 final  Set<Destination> _selected;
@override@JsonKey() Set<Destination> get selected {
  if (_selected is EqualUnmodifiableSetView) return _selected;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_selected);
}

@override@JsonKey() final  PostContent shared;
 final  Map<Destination, DestinationVersion> _versions;
@override@JsonKey() Map<Destination, DestinationVersion> get versions {
  if (_versions is EqualUnmodifiableMapView) return _versions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_versions);
}

@override final  DateTime? deletedAt;

/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DraftCopyWith<_Draft> get copyWith => __$DraftCopyWithImpl<_Draft>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DraftToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Draft&&(identical(other.id, id) || other.id == id)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.sharedTextRevision, sharedTextRevision) || other.sharedTextRevision == sharedTextRevision)&&(identical(other.sharedMediaRevision, sharedMediaRevision) || other.sharedMediaRevision == sharedMediaRevision)&&(identical(other.stage, stage) || other.stage == stage)&&const DeepCollectionEquality().equals(other.selected, _selected)&&(identical(other.shared, shared) || other.shared == shared)&&const DeepCollectionEquality().equals(other.versions, _versions)&&(identical(other.deletedAt, deletedAt) || other.deletedAt == deletedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,updatedAt,revision,sharedTextRevision,sharedMediaRevision,stage,const DeepCollectionEquality().hash(_selected),shared,const DeepCollectionEquality().hash(_versions),deletedAt);
}

@override
String toString() {
    return 'Draft(id: $id, updatedAt: $updatedAt, revision: $revision, sharedTextRevision: $sharedTextRevision, sharedMediaRevision: $sharedMediaRevision, stage: $stage, selected: $selected, shared: $shared, versions: $versions, deletedAt: $deletedAt)';
}


}

/// @nodoc
abstract mixin class _$DraftCopyWith<$Res> implements $DraftCopyWith<$Res> {
  factory _$DraftCopyWith(_Draft value, $Res Function(_Draft) _then) = __$DraftCopyWithImpl;
@override @useResult
$Res call({
 String id, DateTime updatedAt, int revision, int sharedTextRevision, int sharedMediaRevision, ComposeStage stage, Set<Destination> selected, PostContent shared, Map<Destination, DestinationVersion> versions, DateTime? deletedAt
});


@override $PostContentCopyWith<$Res> get shared;

}
/// @nodoc
class __$DraftCopyWithImpl<$Res>
    implements _$DraftCopyWith<$Res> {
  __$DraftCopyWithImpl(this._self, this._then);

  final _Draft _self;
  final $Res Function(_Draft) _then;

/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? updatedAt = null,Object? revision = null,Object? sharedTextRevision = null,Object? sharedMediaRevision = null,Object? stage = null,Object? selected = null,Object? shared = null,Object? versions = null,Object? deletedAt = freezed,}) {
  return _then(_Draft(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,sharedTextRevision: null == sharedTextRevision ? _self.sharedTextRevision : sharedTextRevision // ignore: cast_nullable_to_non_nullable
as int,sharedMediaRevision: null == sharedMediaRevision ? _self.sharedMediaRevision : sharedMediaRevision // ignore: cast_nullable_to_non_nullable
as int,stage: null == stage ? _self.stage : stage // ignore: cast_nullable_to_non_nullable
as ComposeStage,selected: null == selected ? _self._selected : selected // ignore: cast_nullable_to_non_nullable
as Set<Destination>,shared: null == shared ? _self.shared : shared // ignore: cast_nullable_to_non_nullable
as PostContent,versions: null == versions ? _self._versions : versions // ignore: cast_nullable_to_non_nullable
as Map<Destination, DestinationVersion>,deletedAt: freezed == deletedAt ? _self.deletedAt : deletedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of Draft
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostContentCopyWith<$Res> get shared {
  
  return $PostContentCopyWith<$Res>(_self.shared, (value) {
    return _then(_self.copyWith(shared: value));
  });
}
}


/// @nodoc
mixin _$MediaAsset {

 String get id; String get relativePath; String get mimeType; int get bytes; String get sha256; int get width; int get height; int? get durationMs; String? get originalAssetId;
/// Create a copy of MediaAsset
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MediaAssetCopyWith<MediaAsset> get copyWith => _$MediaAssetCopyWithImpl<MediaAsset>(this as MediaAsset, _$identity);

  /// Serializes this MediaAsset to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MediaAsset;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MediaAsset&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.relativePath, _this.relativePath) || other.relativePath == _this.relativePath)&&(identical(other.mimeType, _this.mimeType) || other.mimeType == _this.mimeType)&&(identical(other.bytes, _this.bytes) || other.bytes == _this.bytes)&&(identical(other.sha256, _this.sha256) || other.sha256 == _this.sha256)&&(identical(other.width, _this.width) || other.width == _this.width)&&(identical(other.height, _this.height) || other.height == _this.height)&&(identical(other.durationMs, _this.durationMs) || other.durationMs == _this.durationMs)&&(identical(other.originalAssetId, _this.originalAssetId) || other.originalAssetId == _this.originalAssetId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MediaAsset;
  return Object.hash(runtimeType,_this.id,_this.relativePath,_this.mimeType,_this.bytes,_this.sha256,_this.width,_this.height,_this.durationMs,_this.originalAssetId);
}

@override
String toString() {
  final _this = this as MediaAsset;
  return 'MediaAsset(id: ${_this.id}, relativePath: ${_this.relativePath}, mimeType: ${_this.mimeType}, bytes: ${_this.bytes}, sha256: ${_this.sha256}, width: ${_this.width}, height: ${_this.height}, durationMs: ${_this.durationMs}, originalAssetId: ${_this.originalAssetId})';
}


}

/// @nodoc
abstract mixin class $MediaAssetCopyWith<$Res>  {
  factory $MediaAssetCopyWith(MediaAsset value, $Res Function(MediaAsset) _then) = _$MediaAssetCopyWithImpl;
@useResult
$Res call({
 String id, String relativePath, String mimeType, int bytes, String sha256, int width, int height, int? durationMs, String? originalAssetId
});




}
/// @nodoc
class _$MediaAssetCopyWithImpl<$Res>
    implements $MediaAssetCopyWith<$Res> {
  _$MediaAssetCopyWithImpl(this._self, this._then);

  final MediaAsset _self;
  final $Res Function(MediaAsset) _then;

/// Create a copy of MediaAsset
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? relativePath = null,Object? mimeType = null,Object? bytes = null,Object? sha256 = null,Object? width = null,Object? height = null,Object? durationMs = freezed,Object? originalAssetId = freezed,}) {
  return _then(MediaAsset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,originalAssetId: freezed == originalAssetId ? _self.originalAssetId : originalAssetId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [MediaAsset].
extension MediaAssetPatterns on MediaAsset {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MediaAsset value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MediaAsset() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MediaAsset value)  $default,){
final _that = this;
switch (_that) {
case _MediaAsset():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MediaAsset value)?  $default,){
final _that = this;
switch (_that) {
case _MediaAsset() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String relativePath,  String mimeType,  int bytes,  String sha256,  int width,  int height,  int? durationMs,  String? originalAssetId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MediaAsset() when $default != null:
return $default(_that.id,_that.relativePath,_that.mimeType,_that.bytes,_that.sha256,_that.width,_that.height,_that.durationMs,_that.originalAssetId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String relativePath,  String mimeType,  int bytes,  String sha256,  int width,  int height,  int? durationMs,  String? originalAssetId)  $default,) {final _that = this;
switch (_that) {
case _MediaAsset():
return $default(_that.id,_that.relativePath,_that.mimeType,_that.bytes,_that.sha256,_that.width,_that.height,_that.durationMs,_that.originalAssetId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String relativePath,  String mimeType,  int bytes,  String sha256,  int width,  int height,  int? durationMs,  String? originalAssetId)?  $default,) {final _that = this;
switch (_that) {
case _MediaAsset() when $default != null:
return $default(_that.id,_that.relativePath,_that.mimeType,_that.bytes,_that.sha256,_that.width,_that.height,_that.durationMs,_that.originalAssetId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MediaAsset implements MediaAsset {
  const _MediaAsset({required this.id, required this.relativePath, required this.mimeType, required this.bytes, required this.sha256, required this.width, required this.height, this.durationMs, this.originalAssetId});
  factory _MediaAsset.fromJson(Map<String, dynamic> json) => _$MediaAssetFromJson(json);

@override final  String id;
@override final  String relativePath;
@override final  String mimeType;
@override final  int bytes;
@override final  String sha256;
@override final  int width;
@override final  int height;
@override final  int? durationMs;
@override final  String? originalAssetId;

/// Create a copy of MediaAsset
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MediaAssetCopyWith<_MediaAsset> get copyWith => __$MediaAssetCopyWithImpl<_MediaAsset>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MediaAssetToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MediaAsset&&(identical(other.id, id) || other.id == id)&&(identical(other.relativePath, relativePath) || other.relativePath == relativePath)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.bytes, bytes) || other.bytes == bytes)&&(identical(other.sha256, sha256) || other.sha256 == sha256)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&(identical(other.originalAssetId, originalAssetId) || other.originalAssetId == originalAssetId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,relativePath,mimeType,bytes,sha256,width,height,durationMs,originalAssetId);
}

@override
String toString() {
    return 'MediaAsset(id: $id, relativePath: $relativePath, mimeType: $mimeType, bytes: $bytes, sha256: $sha256, width: $width, height: $height, durationMs: $durationMs, originalAssetId: $originalAssetId)';
}


}

/// @nodoc
abstract mixin class _$MediaAssetCopyWith<$Res> implements $MediaAssetCopyWith<$Res> {
  factory _$MediaAssetCopyWith(_MediaAsset value, $Res Function(_MediaAsset) _then) = __$MediaAssetCopyWithImpl;
@override @useResult
$Res call({
 String id, String relativePath, String mimeType, int bytes, String sha256, int width, int height, int? durationMs, String? originalAssetId
});




}
/// @nodoc
class __$MediaAssetCopyWithImpl<$Res>
    implements _$MediaAssetCopyWith<$Res> {
  __$MediaAssetCopyWithImpl(this._self, this._then);

  final _MediaAsset _self;
  final $Res Function(_MediaAsset) _then;

/// Create a copy of MediaAsset
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? relativePath = null,Object? mimeType = null,Object? bytes = null,Object? sha256 = null,Object? width = null,Object? height = null,Object? durationMs = freezed,Object? originalAssetId = freezed,}) {
  return _then(_MediaAsset(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,relativePath: null == relativePath ? _self.relativePath : relativePath // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,bytes: null == bytes ? _self.bytes : bytes // ignore: cast_nullable_to_non_nullable
as int,sha256: null == sha256 ? _self.sha256 : sha256 // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,originalAssetId: freezed == originalAssetId ? _self.originalAssetId : originalAssetId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
