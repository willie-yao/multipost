// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ResolvedPost {


/// Create a copy of ResolvedPost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ResolvedPostCopyWith<ResolvedPost> get copyWith => _$ResolvedPostCopyWithImpl<ResolvedPost>(this as ResolvedPost, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ResolvedPost;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ResolvedPost&&(identical(other.destination, _this.destination) || other.destination == _this.destination)&&(identical(other.content, _this.content) || other.content == _this.content)&&const DeepCollectionEquality().equals(other.assets, _this.assets)&&(identical(other.account, _this.account) || other.account == _this.account));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ResolvedPost;
  return Object.hash(runtimeType,_this.destination,_this.content,const DeepCollectionEquality().hash(_this.assets),_this.account);
}

@override
String toString() {
  final _this = this as ResolvedPost;
  return 'ResolvedPost(destination: ${_this.destination}, content: ${_this.content}, assets: ${_this.assets}, account: ${_this.account})';
}


}

/// @nodoc
abstract mixin class $ResolvedPostCopyWith<$Res>  {
  factory $ResolvedPostCopyWith(ResolvedPost value, $Res Function(ResolvedPost) _then) = _$ResolvedPostCopyWithImpl;
@useResult
$Res call({
 Destination destination, PostContent content, List<MediaAsset> assets, AccountIdentity? account
});


$PostContentCopyWith<$Res> get content;$AccountIdentityCopyWith<$Res>? get account;

}
/// @nodoc
class _$ResolvedPostCopyWithImpl<$Res>
    implements $ResolvedPostCopyWith<$Res> {
  _$ResolvedPostCopyWithImpl(this._self, this._then);

  final ResolvedPost _self;
  final $Res Function(ResolvedPost) _then;

/// Create a copy of ResolvedPost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? destination = null,Object? content = null,Object? assets = null,Object? account = freezed,}) {
  return _then(ResolvedPost(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as PostContent,assets: null == assets ? _self.assets : assets // ignore: cast_nullable_to_non_nullable
as List<MediaAsset>,account: freezed == account ? _self.account : account // ignore: cast_nullable_to_non_nullable
as AccountIdentity?,
  ));
}
/// Create a copy of ResolvedPost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PostContentCopyWith<$Res> get content {
  
  return $PostContentCopyWith<$Res>(_self.content, (value) {
    return _then(_self.copyWith(content: value));
  });
}/// Create a copy of ResolvedPost
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountIdentityCopyWith<$Res>? get account {
    if (_self.account == null) {
    return null;
  }

  return $AccountIdentityCopyWith<$Res>(_self.account!, (value) {
    return _then(_self.copyWith(account: value));
  });
}
}


/// Adds pattern-matching-related methods to [ResolvedPost].
extension ResolvedPostPatterns on ResolvedPost {
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
mixin _$ReviewIssue {

 Destination get destination; String get code; String get message; bool get blocking;
/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewIssueCopyWith<ReviewIssue> get copyWith => _$ReviewIssueCopyWithImpl<ReviewIssue>(this as ReviewIssue, _$identity);

  /// Serializes this ReviewIssue to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReviewIssue;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewIssue&&(identical(other.destination, _this.destination) || other.destination == _this.destination)&&(identical(other.code, _this.code) || other.code == _this.code)&&(identical(other.message, _this.message) || other.message == _this.message)&&(identical(other.blocking, _this.blocking) || other.blocking == _this.blocking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewIssue;
  return Object.hash(runtimeType,_this.destination,_this.code,_this.message,_this.blocking);
}

@override
String toString() {
  final _this = this as ReviewIssue;
  return 'ReviewIssue(destination: ${_this.destination}, code: ${_this.code}, message: ${_this.message}, blocking: ${_this.blocking})';
}


}

/// @nodoc
abstract mixin class $ReviewIssueCopyWith<$Res>  {
  factory $ReviewIssueCopyWith(ReviewIssue value, $Res Function(ReviewIssue) _then) = _$ReviewIssueCopyWithImpl;
@useResult
$Res call({
 Destination destination, String code, String message, bool blocking
});




}
/// @nodoc
class _$ReviewIssueCopyWithImpl<$Res>
    implements $ReviewIssueCopyWith<$Res> {
  _$ReviewIssueCopyWithImpl(this._self, this._then);

  final ReviewIssue _self;
  final $Res Function(ReviewIssue) _then;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? destination = null,Object? code = null,Object? message = null,Object? blocking = null,}) {
  return _then(ReviewIssue(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,blocking: null == blocking ? _self.blocking : blocking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewIssue].
extension ReviewIssuePatterns on ReviewIssue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReviewIssue value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReviewIssue value)  $default,){
final _that = this;
switch (_that) {
case _ReviewIssue():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReviewIssue value)?  $default,){
final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Destination destination,  String code,  String message,  bool blocking)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
return $default(_that.destination,_that.code,_that.message,_that.blocking);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Destination destination,  String code,  String message,  bool blocking)  $default,) {final _that = this;
switch (_that) {
case _ReviewIssue():
return $default(_that.destination,_that.code,_that.message,_that.blocking);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Destination destination,  String code,  String message,  bool blocking)?  $default,) {final _that = this;
switch (_that) {
case _ReviewIssue() when $default != null:
return $default(_that.destination,_that.code,_that.message,_that.blocking);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReviewIssue implements ReviewIssue {
  const _ReviewIssue({required this.destination, required this.code, required this.message, required this.blocking});
  factory _ReviewIssue.fromJson(Map<String, dynamic> json) => _$ReviewIssueFromJson(json);

@override final  Destination destination;
@override final  String code;
@override final  String message;
@override final  bool blocking;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReviewIssueCopyWith<_ReviewIssue> get copyWith => __$ReviewIssueCopyWithImpl<_ReviewIssue>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReviewIssueToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReviewIssue&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.code, code) || other.code == code)&&(identical(other.message, message) || other.message == message)&&(identical(other.blocking, blocking) || other.blocking == blocking));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,destination,code,message,blocking);
}

@override
String toString() {
    return 'ReviewIssue(destination: $destination, code: $code, message: $message, blocking: $blocking)';
}


}

/// @nodoc
abstract mixin class _$ReviewIssueCopyWith<$Res> implements $ReviewIssueCopyWith<$Res> {
  factory _$ReviewIssueCopyWith(_ReviewIssue value, $Res Function(_ReviewIssue) _then) = __$ReviewIssueCopyWithImpl;
@override @useResult
$Res call({
 Destination destination, String code, String message, bool blocking
});




}
/// @nodoc
class __$ReviewIssueCopyWithImpl<$Res>
    implements _$ReviewIssueCopyWith<$Res> {
  __$ReviewIssueCopyWithImpl(this._self, this._then);

  final _ReviewIssue _self;
  final $Res Function(_ReviewIssue) _then;

/// Create a copy of ReviewIssue
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? destination = null,Object? code = null,Object? message = null,Object? blocking = null,}) {
  return _then(_ReviewIssue(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as String,message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,blocking: null == blocking ? _self.blocking : blocking // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$ReviewedPost {


/// Create a copy of ReviewedPost
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewedPostCopyWith<ReviewedPost> get copyWith => _$ReviewedPostCopyWithImpl<ReviewedPost>(this as ReviewedPost, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReviewedPost;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewedPost&&(identical(other.draftId, _this.draftId) || other.draftId == _this.draftId)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.posts, _this.posts)&&const DeepCollectionEquality().equals(other.capabilityVersions, _this.capabilityVersions)&&(identical(other.reviewedAt, _this.reviewedAt) || other.reviewedAt == _this.reviewedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewedPost;
  return Object.hash(runtimeType,_this.draftId,_this.revision,const DeepCollectionEquality().hash(_this.posts),const DeepCollectionEquality().hash(_this.capabilityVersions),_this.reviewedAt);
}

@override
String toString() {
  final _this = this as ReviewedPost;
  return 'ReviewedPost(draftId: ${_this.draftId}, revision: ${_this.revision}, posts: ${_this.posts}, capabilityVersions: ${_this.capabilityVersions}, reviewedAt: ${_this.reviewedAt})';
}


}

/// @nodoc
abstract mixin class $ReviewedPostCopyWith<$Res>  {
  factory $ReviewedPostCopyWith(ReviewedPost value, $Res Function(ReviewedPost) _then) = _$ReviewedPostCopyWithImpl;
@useResult
$Res call({
 String draftId, int revision, Map<Destination, ResolvedPost> posts, Map<Destination, String> capabilityVersions, DateTime reviewedAt
});




}
/// @nodoc
class _$ReviewedPostCopyWithImpl<$Res>
    implements $ReviewedPostCopyWith<$Res> {
  _$ReviewedPostCopyWithImpl(this._self, this._then);

  final ReviewedPost _self;
  final $Res Function(ReviewedPost) _then;

/// Create a copy of ReviewedPost
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? draftId = null,Object? revision = null,Object? posts = null,Object? capabilityVersions = null,Object? reviewedAt = null,}) {
  return _then(ReviewedPost(
draftId: null == draftId ? _self.draftId : draftId // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,posts: null == posts ? _self.posts : posts // ignore: cast_nullable_to_non_nullable
as Map<Destination, ResolvedPost>,capabilityVersions: null == capabilityVersions ? _self.capabilityVersions : capabilityVersions // ignore: cast_nullable_to_non_nullable
as Map<Destination, String>,reviewedAt: null == reviewedAt ? _self.reviewedAt : reviewedAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [ReviewedPost].
extension ReviewedPostPatterns on ReviewedPost {
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
mixin _$ReviewResult {


/// Create a copy of ReviewResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReviewResultCopyWith<ReviewResult> get copyWith => _$ReviewResultCopyWithImpl<ReviewResult>(this as ReviewResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ReviewResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReviewResult&&(identical(other.snapshot, _this.snapshot) || other.snapshot == _this.snapshot)&&const DeepCollectionEquality().equals(other.issues, _this.issues));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReviewResult;
  return Object.hash(runtimeType,_this.snapshot,const DeepCollectionEquality().hash(_this.issues));
}

@override
String toString() {
  final _this = this as ReviewResult;
  return 'ReviewResult(snapshot: ${_this.snapshot}, issues: ${_this.issues})';
}


}

/// @nodoc
abstract mixin class $ReviewResultCopyWith<$Res>  {
  factory $ReviewResultCopyWith(ReviewResult value, $Res Function(ReviewResult) _then) = _$ReviewResultCopyWithImpl;
@useResult
$Res call({
 ReviewedPost snapshot, List<ReviewIssue> issues
});


$ReviewedPostCopyWith<$Res> get snapshot;

}
/// @nodoc
class _$ReviewResultCopyWithImpl<$Res>
    implements $ReviewResultCopyWith<$Res> {
  _$ReviewResultCopyWithImpl(this._self, this._then);

  final ReviewResult _self;
  final $Res Function(ReviewResult) _then;

/// Create a copy of ReviewResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snapshot = null,Object? issues = null,}) {
  return _then(ReviewResult(
snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as ReviewedPost,issues: null == issues ? _self.issues : issues // ignore: cast_nullable_to_non_nullable
as List<ReviewIssue>,
  ));
}
/// Create a copy of ReviewResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReviewedPostCopyWith<$Res> get snapshot {
  
  return $ReviewedPostCopyWith<$Res>(_self.snapshot, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReviewResult].
extension ReviewResultPatterns on ReviewResult {
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
