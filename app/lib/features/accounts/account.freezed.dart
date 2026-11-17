// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'account.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AccountIdentity {

 Destination get destination; String get subject; String get handle;
/// Create a copy of AccountIdentity
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountIdentityCopyWith<AccountIdentity> get copyWith => _$AccountIdentityCopyWithImpl<AccountIdentity>(this as AccountIdentity, _$identity);

  /// Serializes this AccountIdentity to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AccountIdentity;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountIdentity&&(identical(other.destination, _this.destination) || other.destination == _this.destination)&&(identical(other.subject, _this.subject) || other.subject == _this.subject)&&(identical(other.handle, _this.handle) || other.handle == _this.handle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AccountIdentity;
  return Object.hash(runtimeType,_this.destination,_this.subject,_this.handle);
}

@override
String toString() {
  final _this = this as AccountIdentity;
  return 'AccountIdentity(destination: ${_this.destination}, subject: ${_this.subject}, handle: ${_this.handle})';
}


}

/// @nodoc
abstract mixin class $AccountIdentityCopyWith<$Res>  {
  factory $AccountIdentityCopyWith(AccountIdentity value, $Res Function(AccountIdentity) _then) = _$AccountIdentityCopyWithImpl;
@useResult
$Res call({
 Destination destination, String subject, String handle
});




}
/// @nodoc
class _$AccountIdentityCopyWithImpl<$Res>
    implements $AccountIdentityCopyWith<$Res> {
  _$AccountIdentityCopyWithImpl(this._self, this._then);

  final AccountIdentity _self;
  final $Res Function(AccountIdentity) _then;

/// Create a copy of AccountIdentity
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? destination = null,Object? subject = null,Object? handle = null,}) {
  return _then(AccountIdentity(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AccountIdentity].
extension AccountIdentityPatterns on AccountIdentity {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountIdentity value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountIdentity() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountIdentity value)  $default,){
final _that = this;
switch (_that) {
case _AccountIdentity():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountIdentity value)?  $default,){
final _that = this;
switch (_that) {
case _AccountIdentity() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Destination destination,  String subject,  String handle)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountIdentity() when $default != null:
return $default(_that.destination,_that.subject,_that.handle);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Destination destination,  String subject,  String handle)  $default,) {final _that = this;
switch (_that) {
case _AccountIdentity():
return $default(_that.destination,_that.subject,_that.handle);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Destination destination,  String subject,  String handle)?  $default,) {final _that = this;
switch (_that) {
case _AccountIdentity() when $default != null:
return $default(_that.destination,_that.subject,_that.handle);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountIdentity implements AccountIdentity {
  const _AccountIdentity({required this.destination, required this.subject, required this.handle});
  factory _AccountIdentity.fromJson(Map<String, dynamic> json) => _$AccountIdentityFromJson(json);

@override final  Destination destination;
@override final  String subject;
@override final  String handle;

/// Create a copy of AccountIdentity
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountIdentityCopyWith<_AccountIdentity> get copyWith => __$AccountIdentityCopyWithImpl<_AccountIdentity>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountIdentityToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountIdentity&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.subject, subject) || other.subject == subject)&&(identical(other.handle, handle) || other.handle == handle));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,destination,subject,handle);
}

@override
String toString() {
    return 'AccountIdentity(destination: $destination, subject: $subject, handle: $handle)';
}


}

/// @nodoc
abstract mixin class _$AccountIdentityCopyWith<$Res> implements $AccountIdentityCopyWith<$Res> {
  factory _$AccountIdentityCopyWith(_AccountIdentity value, $Res Function(_AccountIdentity) _then) = __$AccountIdentityCopyWithImpl;
@override @useResult
$Res call({
 Destination destination, String subject, String handle
});




}
/// @nodoc
class __$AccountIdentityCopyWithImpl<$Res>
    implements _$AccountIdentityCopyWith<$Res> {
  __$AccountIdentityCopyWithImpl(this._self, this._then);

  final _AccountIdentity _self;
  final $Res Function(_AccountIdentity) _then;

/// Create a copy of AccountIdentity
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? destination = null,Object? subject = null,Object? handle = null,}) {
  return _then(_AccountIdentity(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,subject: null == subject ? _self.subject : subject // ignore: cast_nullable_to_non_nullable
as String,handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$AccountView {

 Destination get destination; AccountState get state; AccountIdentity? get identity; String get capability;
/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AccountViewCopyWith<AccountView> get copyWith => _$AccountViewCopyWithImpl<AccountView>(this as AccountView, _$identity);

  /// Serializes this AccountView to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AccountView;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AccountView&&(identical(other.destination, _this.destination) || other.destination == _this.destination)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.identity, _this.identity) || other.identity == _this.identity)&&(identical(other.capability, _this.capability) || other.capability == _this.capability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AccountView;
  return Object.hash(runtimeType,_this.destination,_this.state,_this.identity,_this.capability);
}

@override
String toString() {
  final _this = this as AccountView;
  return 'AccountView(destination: ${_this.destination}, state: ${_this.state}, identity: ${_this.identity}, capability: ${_this.capability})';
}


}

/// @nodoc
abstract mixin class $AccountViewCopyWith<$Res>  {
  factory $AccountViewCopyWith(AccountView value, $Res Function(AccountView) _then) = _$AccountViewCopyWithImpl;
@useResult
$Res call({
 Destination destination, AccountState state, AccountIdentity? identity, String capability
});


$AccountIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class _$AccountViewCopyWithImpl<$Res>
    implements $AccountViewCopyWith<$Res> {
  _$AccountViewCopyWithImpl(this._self, this._then);

  final AccountView _self;
  final $Res Function(AccountView) _then;

/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? destination = null,Object? state = null,Object? identity = freezed,Object? capability = null,}) {
  return _then(AccountView(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as AccountState,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as AccountIdentity?,capability: null == capability ? _self.capability : capability // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $AccountIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}


/// Adds pattern-matching-related methods to [AccountView].
extension AccountViewPatterns on AccountView {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AccountView value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AccountView() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AccountView value)  $default,){
final _that = this;
switch (_that) {
case _AccountView():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AccountView value)?  $default,){
final _that = this;
switch (_that) {
case _AccountView() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Destination destination,  AccountState state,  AccountIdentity? identity,  String capability)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AccountView() when $default != null:
return $default(_that.destination,_that.state,_that.identity,_that.capability);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Destination destination,  AccountState state,  AccountIdentity? identity,  String capability)  $default,) {final _that = this;
switch (_that) {
case _AccountView():
return $default(_that.destination,_that.state,_that.identity,_that.capability);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Destination destination,  AccountState state,  AccountIdentity? identity,  String capability)?  $default,) {final _that = this;
switch (_that) {
case _AccountView() when $default != null:
return $default(_that.destination,_that.state,_that.identity,_that.capability);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AccountView implements AccountView {
  const _AccountView({required this.destination, required this.state, this.identity, required this.capability});
  factory _AccountView.fromJson(Map<String, dynamic> json) => _$AccountViewFromJson(json);

@override final  Destination destination;
@override final  AccountState state;
@override final  AccountIdentity? identity;
@override final  String capability;

/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AccountViewCopyWith<_AccountView> get copyWith => __$AccountViewCopyWithImpl<_AccountView>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AccountViewToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AccountView&&(identical(other.destination, destination) || other.destination == destination)&&(identical(other.state, state) || other.state == state)&&(identical(other.identity, identity) || other.identity == identity)&&(identical(other.capability, capability) || other.capability == capability));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,destination,state,identity,capability);
}

@override
String toString() {
    return 'AccountView(destination: $destination, state: $state, identity: $identity, capability: $capability)';
}


}

/// @nodoc
abstract mixin class _$AccountViewCopyWith<$Res> implements $AccountViewCopyWith<$Res> {
  factory _$AccountViewCopyWith(_AccountView value, $Res Function(_AccountView) _then) = __$AccountViewCopyWithImpl;
@override @useResult
$Res call({
 Destination destination, AccountState state, AccountIdentity? identity, String capability
});


@override $AccountIdentityCopyWith<$Res>? get identity;

}
/// @nodoc
class __$AccountViewCopyWithImpl<$Res>
    implements _$AccountViewCopyWith<$Res> {
  __$AccountViewCopyWithImpl(this._self, this._then);

  final _AccountView _self;
  final $Res Function(_AccountView) _then;

/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? destination = null,Object? state = null,Object? identity = freezed,Object? capability = null,}) {
  return _then(_AccountView(
destination: null == destination ? _self.destination : destination // ignore: cast_nullable_to_non_nullable
as Destination,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as AccountState,identity: freezed == identity ? _self.identity : identity // ignore: cast_nullable_to_non_nullable
as AccountIdentity?,capability: null == capability ? _self.capability : capability // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of AccountView
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AccountIdentityCopyWith<$Res>? get identity {
    if (_self.identity == null) {
    return null;
  }

  return $AccountIdentityCopyWith<$Res>(_self.identity!, (value) {
    return _then(_self.copyWith(identity: value));
  });
}
}

// dart format on
