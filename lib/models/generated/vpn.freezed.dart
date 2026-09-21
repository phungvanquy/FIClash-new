// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of '../vpn.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CoreRunObservation {

 String get session; int get revision; bool get requested; bool get active; bool get suspended; bool get tun; int get mixedPort; String? get generation; int? get configRevision; String? get failure;
/// Create a copy of CoreRunObservation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoreRunObservationCopyWith<CoreRunObservation> get copyWith => _$CoreRunObservationCopyWithImpl<CoreRunObservation>(this as CoreRunObservation, _$identity);

  /// Serializes this CoreRunObservation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as CoreRunObservation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CoreRunObservation&&(identical(other.session, _this.session) || other.session == _this.session)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.requested, _this.requested) || other.requested == _this.requested)&&(identical(other.active, _this.active) || other.active == _this.active)&&(identical(other.suspended, _this.suspended) || other.suspended == _this.suspended)&&(identical(other.tun, _this.tun) || other.tun == _this.tun)&&(identical(other.mixedPort, _this.mixedPort) || other.mixedPort == _this.mixedPort)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.configRevision, _this.configRevision) || other.configRevision == _this.configRevision)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as CoreRunObservation;
  return Object.hash(runtimeType,_this.session,_this.revision,_this.requested,_this.active,_this.suspended,_this.tun,_this.mixedPort,_this.generation,_this.configRevision,_this.failure);
}

@override
String toString() {
  final _this = this as CoreRunObservation;
  return 'CoreRunObservation(session: ${_this.session}, revision: ${_this.revision}, requested: ${_this.requested}, active: ${_this.active}, suspended: ${_this.suspended}, tun: ${_this.tun}, mixedPort: ${_this.mixedPort}, generation: ${_this.generation}, configRevision: ${_this.configRevision}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $CoreRunObservationCopyWith<$Res>  {
  factory $CoreRunObservationCopyWith(CoreRunObservation value, $Res Function(CoreRunObservation) _then) = _$CoreRunObservationCopyWithImpl;
@useResult
$Res call({
 String session, int revision, bool requested, bool active, bool suspended, bool tun, int mixedPort, String? generation, int? configRevision, String? failure
});




}
/// @nodoc
class _$CoreRunObservationCopyWithImpl<$Res>
    implements $CoreRunObservationCopyWith<$Res> {
  _$CoreRunObservationCopyWithImpl(this._self, this._then);

  final CoreRunObservation _self;
  final $Res Function(CoreRunObservation) _then;

/// Create a copy of CoreRunObservation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,Object? revision = null,Object? requested = null,Object? active = null,Object? suspended = null,Object? tun = null,Object? mixedPort = null,Object? generation = freezed,Object? configRevision = freezed,Object? failure = freezed,}) {
  return _then(CoreRunObservation(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,requested: null == requested ? _self.requested : requested // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,suspended: null == suspended ? _self.suspended : suspended // ignore: cast_nullable_to_non_nullable
as bool,tun: null == tun ? _self.tun : tun // ignore: cast_nullable_to_non_nullable
as bool,mixedPort: null == mixedPort ? _self.mixedPort : mixedPort // ignore: cast_nullable_to_non_nullable
as int,generation: freezed == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String?,configRevision: freezed == configRevision ? _self.configRevision : configRevision // ignore: cast_nullable_to_non_nullable
as int?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CoreRunObservation].
extension CoreRunObservationPatterns on CoreRunObservation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CoreRunObservation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CoreRunObservation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CoreRunObservation value)  $default,){
final _that = this;
switch (_that) {
case _CoreRunObservation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CoreRunObservation value)?  $default,){
final _that = this;
switch (_that) {
case _CoreRunObservation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String session,  int revision,  bool requested,  bool active,  bool suspended,  bool tun,  int mixedPort,  String? generation,  int? configRevision,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CoreRunObservation() when $default != null:
return $default(_that.session,_that.revision,_that.requested,_that.active,_that.suspended,_that.tun,_that.mixedPort,_that.generation,_that.configRevision,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String session,  int revision,  bool requested,  bool active,  bool suspended,  bool tun,  int mixedPort,  String? generation,  int? configRevision,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _CoreRunObservation():
return $default(_that.session,_that.revision,_that.requested,_that.active,_that.suspended,_that.tun,_that.mixedPort,_that.generation,_that.configRevision,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String session,  int revision,  bool requested,  bool active,  bool suspended,  bool tun,  int mixedPort,  String? generation,  int? configRevision,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _CoreRunObservation() when $default != null:
return $default(_that.session,_that.revision,_that.requested,_that.active,_that.suspended,_that.tun,_that.mixedPort,_that.generation,_that.configRevision,_that.failure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CoreRunObservation implements CoreRunObservation {
  const _CoreRunObservation({required this.session, required this.revision, this.requested = false, this.active = false, this.suspended = false, this.tun = false, this.mixedPort = 0, this.generation, this.configRevision, this.failure});
  factory _CoreRunObservation.fromJson(Map<String, dynamic> json) => _$CoreRunObservationFromJson(json);

@override final  String session;
@override final  int revision;
@override@JsonKey() final  bool requested;
@override@JsonKey() final  bool active;
@override@JsonKey() final  bool suspended;
@override@JsonKey() final  bool tun;
@override@JsonKey() final  int mixedPort;
@override final  String? generation;
@override final  int? configRevision;
@override final  String? failure;

/// Create a copy of CoreRunObservation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoreRunObservationCopyWith<_CoreRunObservation> get copyWith => __$CoreRunObservationCopyWithImpl<_CoreRunObservation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CoreRunObservationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _CoreRunObservation&&(identical(other.session, session) || other.session == session)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.requested, requested) || other.requested == requested)&&(identical(other.active, active) || other.active == active)&&(identical(other.suspended, suspended) || other.suspended == suspended)&&(identical(other.tun, tun) || other.tun == tun)&&(identical(other.mixedPort, mixedPort) || other.mixedPort == mixedPort)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.configRevision, configRevision) || other.configRevision == configRevision)&&(identical(other.failure, failure) || other.failure == failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,session,revision,requested,active,suspended,tun,mixedPort,generation,configRevision,failure);
}

@override
String toString() {
    return 'CoreRunObservation(session: $session, revision: $revision, requested: $requested, active: $active, suspended: $suspended, tun: $tun, mixedPort: $mixedPort, generation: $generation, configRevision: $configRevision, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$CoreRunObservationCopyWith<$Res> implements $CoreRunObservationCopyWith<$Res> {
  factory _$CoreRunObservationCopyWith(_CoreRunObservation value, $Res Function(_CoreRunObservation) _then) = __$CoreRunObservationCopyWithImpl;
@override @useResult
$Res call({
 String session, int revision, bool requested, bool active, bool suspended, bool tun, int mixedPort, String? generation, int? configRevision, String? failure
});




}
/// @nodoc
class __$CoreRunObservationCopyWithImpl<$Res>
    implements _$CoreRunObservationCopyWith<$Res> {
  __$CoreRunObservationCopyWithImpl(this._self, this._then);

  final _CoreRunObservation _self;
  final $Res Function(_CoreRunObservation) _then;

/// Create a copy of CoreRunObservation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,Object? revision = null,Object? requested = null,Object? active = null,Object? suspended = null,Object? tun = null,Object? mixedPort = null,Object? generation = freezed,Object? configRevision = freezed,Object? failure = freezed,}) {
  return _then(_CoreRunObservation(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,requested: null == requested ? _self.requested : requested // ignore: cast_nullable_to_non_nullable
as bool,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,suspended: null == suspended ? _self.suspended : suspended // ignore: cast_nullable_to_non_nullable
as bool,tun: null == tun ? _self.tun : tun // ignore: cast_nullable_to_non_nullable
as bool,mixedPort: null == mixedPort ? _self.mixedPort : mixedPort // ignore: cast_nullable_to_non_nullable
as int,generation: freezed == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String?,configRevision: freezed == configRevision ? _self.configRevision : configRevision // ignore: cast_nullable_to_non_nullable
as int?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$VpnConnection {

 VpnConnectionPhase get phase; bool get canDisconnect; String? get failure;
/// Create a copy of VpnConnection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnConnectionCopyWith<VpnConnection> get copyWith => _$VpnConnectionCopyWithImpl<VpnConnection>(this as VpnConnection, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as VpnConnection;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnConnection&&(identical(other.phase, _this.phase) || other.phase == _this.phase)&&(identical(other.canDisconnect, _this.canDisconnect) || other.canDisconnect == _this.canDisconnect)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as VpnConnection;
  return Object.hash(runtimeType,_this.phase,_this.canDisconnect,_this.failure);
}

@override
String toString() {
  final _this = this as VpnConnection;
  return 'VpnConnection(phase: ${_this.phase}, canDisconnect: ${_this.canDisconnect}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $VpnConnectionCopyWith<$Res>  {
  factory $VpnConnectionCopyWith(VpnConnection value, $Res Function(VpnConnection) _then) = _$VpnConnectionCopyWithImpl;
@useResult
$Res call({
 VpnConnectionPhase phase, bool canDisconnect, String? failure
});




}
/// @nodoc
class _$VpnConnectionCopyWithImpl<$Res>
    implements $VpnConnectionCopyWith<$Res> {
  _$VpnConnectionCopyWithImpl(this._self, this._then);

  final VpnConnection _self;
  final $Res Function(VpnConnection) _then;

/// Create a copy of VpnConnection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? canDisconnect = null,Object? failure = freezed,}) {
  return _then(VpnConnection(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as VpnConnectionPhase,canDisconnect: null == canDisconnect ? _self.canDisconnect : canDisconnect // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VpnConnection].
extension VpnConnectionPatterns on VpnConnection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnConnection value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnConnection() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnConnection value)  $default,){
final _that = this;
switch (_that) {
case _VpnConnection():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnConnection value)?  $default,){
final _that = this;
switch (_that) {
case _VpnConnection() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( VpnConnectionPhase phase,  bool canDisconnect,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnConnection() when $default != null:
return $default(_that.phase,_that.canDisconnect,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( VpnConnectionPhase phase,  bool canDisconnect,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _VpnConnection():
return $default(_that.phase,_that.canDisconnect,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( VpnConnectionPhase phase,  bool canDisconnect,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _VpnConnection() when $default != null:
return $default(_that.phase,_that.canDisconnect,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _VpnConnection implements VpnConnection {
  const _VpnConnection({this.phase = VpnConnectionPhase.disconnected, this.canDisconnect = false, this.failure});
  

@override@JsonKey() final  VpnConnectionPhase phase;
@override@JsonKey() final  bool canDisconnect;
@override final  String? failure;

/// Create a copy of VpnConnection
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnConnectionCopyWith<_VpnConnection> get copyWith => __$VpnConnectionCopyWithImpl<_VpnConnection>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnConnection&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.canDisconnect, canDisconnect) || other.canDisconnect == canDisconnect)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,phase,canDisconnect,failure);
}

@override
String toString() {
    return 'VpnConnection(phase: $phase, canDisconnect: $canDisconnect, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$VpnConnectionCopyWith<$Res> implements $VpnConnectionCopyWith<$Res> {
  factory _$VpnConnectionCopyWith(_VpnConnection value, $Res Function(_VpnConnection) _then) = __$VpnConnectionCopyWithImpl;
@override @useResult
$Res call({
 VpnConnectionPhase phase, bool canDisconnect, String? failure
});




}
/// @nodoc
class __$VpnConnectionCopyWithImpl<$Res>
    implements _$VpnConnectionCopyWith<$Res> {
  __$VpnConnectionCopyWithImpl(this._self, this._then);

  final _VpnConnection _self;
  final $Res Function(_VpnConnection) _then;

/// Create a copy of VpnConnection
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? canDisconnect = null,Object? failure = freezed,}) {
  return _then(_VpnConnection(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as VpnConnectionPhase,canDisconnect: null == canDisconnect ? _self.canDisconnect : canDisconnect // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$SystemProxyObservation {

 bool get pending; bool get installed; int get port; String? get failure;
/// Create a copy of SystemProxyObservation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SystemProxyObservationCopyWith<SystemProxyObservation> get copyWith => _$SystemProxyObservationCopyWithImpl<SystemProxyObservation>(this as SystemProxyObservation, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SystemProxyObservation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SystemProxyObservation&&(identical(other.pending, _this.pending) || other.pending == _this.pending)&&(identical(other.installed, _this.installed) || other.installed == _this.installed)&&(identical(other.port, _this.port) || other.port == _this.port)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}


@override
int get hashCode {
  final _this = this as SystemProxyObservation;
  return Object.hash(runtimeType,_this.pending,_this.installed,_this.port,_this.failure);
}

@override
String toString() {
  final _this = this as SystemProxyObservation;
  return 'SystemProxyObservation(pending: ${_this.pending}, installed: ${_this.installed}, port: ${_this.port}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $SystemProxyObservationCopyWith<$Res>  {
  factory $SystemProxyObservationCopyWith(SystemProxyObservation value, $Res Function(SystemProxyObservation) _then) = _$SystemProxyObservationCopyWithImpl;
@useResult
$Res call({
 bool pending, bool installed, int port, String? failure
});




}
/// @nodoc
class _$SystemProxyObservationCopyWithImpl<$Res>
    implements $SystemProxyObservationCopyWith<$Res> {
  _$SystemProxyObservationCopyWithImpl(this._self, this._then);

  final SystemProxyObservation _self;
  final $Res Function(SystemProxyObservation) _then;

/// Create a copy of SystemProxyObservation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pending = null,Object? installed = null,Object? port = null,Object? failure = freezed,}) {
  return _then(SystemProxyObservation(
pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,installed: null == installed ? _self.installed : installed // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SystemProxyObservation].
extension SystemProxyObservationPatterns on SystemProxyObservation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SystemProxyObservation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SystemProxyObservation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SystemProxyObservation value)  $default,){
final _that = this;
switch (_that) {
case _SystemProxyObservation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SystemProxyObservation value)?  $default,){
final _that = this;
switch (_that) {
case _SystemProxyObservation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool pending,  bool installed,  int port,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SystemProxyObservation() when $default != null:
return $default(_that.pending,_that.installed,_that.port,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool pending,  bool installed,  int port,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _SystemProxyObservation():
return $default(_that.pending,_that.installed,_that.port,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool pending,  bool installed,  int port,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _SystemProxyObservation() when $default != null:
return $default(_that.pending,_that.installed,_that.port,_that.failure);case _:
  return null;

}
}

}

/// @nodoc


class _SystemProxyObservation implements SystemProxyObservation {
  const _SystemProxyObservation({this.pending = false, this.installed = false, this.port = 0, this.failure});
  

@override@JsonKey() final  bool pending;
@override@JsonKey() final  bool installed;
@override@JsonKey() final  int port;
@override final  String? failure;

/// Create a copy of SystemProxyObservation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SystemProxyObservationCopyWith<_SystemProxyObservation> get copyWith => __$SystemProxyObservationCopyWithImpl<_SystemProxyObservation>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SystemProxyObservation&&(identical(other.pending, pending) || other.pending == pending)&&(identical(other.installed, installed) || other.installed == installed)&&(identical(other.port, port) || other.port == port)&&(identical(other.failure, failure) || other.failure == failure));
}


@override
int get hashCode {
    return Object.hash(runtimeType,pending,installed,port,failure);
}

@override
String toString() {
    return 'SystemProxyObservation(pending: $pending, installed: $installed, port: $port, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$SystemProxyObservationCopyWith<$Res> implements $SystemProxyObservationCopyWith<$Res> {
  factory _$SystemProxyObservationCopyWith(_SystemProxyObservation value, $Res Function(_SystemProxyObservation) _then) = __$SystemProxyObservationCopyWithImpl;
@override @useResult
$Res call({
 bool pending, bool installed, int port, String? failure
});




}
/// @nodoc
class __$SystemProxyObservationCopyWithImpl<$Res>
    implements _$SystemProxyObservationCopyWith<$Res> {
  __$SystemProxyObservationCopyWithImpl(this._self, this._then);

  final _SystemProxyObservation _self;
  final $Res Function(_SystemProxyObservation) _then;

/// Create a copy of SystemProxyObservation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pending = null,Object? installed = null,Object? port = null,Object? failure = freezed,}) {
  return _then(_SystemProxyObservation(
pending: null == pending ? _self.pending : pending // ignore: cast_nullable_to_non_nullable
as bool,installed: null == installed ? _self.installed : installed // ignore: cast_nullable_to_non_nullable
as bool,port: null == port ? _self.port : port // ignore: cast_nullable_to_non_nullable
as int,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$AndroidRunObservation {

 String get session; int get revision; VpnRunState get state; int get startedAt; bool get vpn; String? get failure;
/// Create a copy of AndroidRunObservation
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AndroidRunObservationCopyWith<AndroidRunObservation> get copyWith => _$AndroidRunObservationCopyWithImpl<AndroidRunObservation>(this as AndroidRunObservation, _$identity);

  /// Serializes this AndroidRunObservation to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as AndroidRunObservation;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AndroidRunObservation&&(identical(other.session, _this.session) || other.session == _this.session)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.state, _this.state) || other.state == _this.state)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.vpn, _this.vpn) || other.vpn == _this.vpn)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as AndroidRunObservation;
  return Object.hash(runtimeType,_this.session,_this.revision,_this.state,_this.startedAt,_this.vpn,_this.failure);
}

@override
String toString() {
  final _this = this as AndroidRunObservation;
  return 'AndroidRunObservation(session: ${_this.session}, revision: ${_this.revision}, state: ${_this.state}, startedAt: ${_this.startedAt}, vpn: ${_this.vpn}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $AndroidRunObservationCopyWith<$Res>  {
  factory $AndroidRunObservationCopyWith(AndroidRunObservation value, $Res Function(AndroidRunObservation) _then) = _$AndroidRunObservationCopyWithImpl;
@useResult
$Res call({
 String session, int revision, VpnRunState state, int startedAt, bool vpn, String? failure
});




}
/// @nodoc
class _$AndroidRunObservationCopyWithImpl<$Res>
    implements $AndroidRunObservationCopyWith<$Res> {
  _$AndroidRunObservationCopyWithImpl(this._self, this._then);

  final AndroidRunObservation _self;
  final $Res Function(AndroidRunObservation) _then;

/// Create a copy of AndroidRunObservation
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? session = null,Object? revision = null,Object? state = null,Object? startedAt = null,Object? vpn = null,Object? failure = freezed,}) {
  return _then(AndroidRunObservation(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as VpnRunState,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int,vpn: null == vpn ? _self.vpn : vpn // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AndroidRunObservation].
extension AndroidRunObservationPatterns on AndroidRunObservation {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AndroidRunObservation value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AndroidRunObservation() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AndroidRunObservation value)  $default,){
final _that = this;
switch (_that) {
case _AndroidRunObservation():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AndroidRunObservation value)?  $default,){
final _that = this;
switch (_that) {
case _AndroidRunObservation() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String session,  int revision,  VpnRunState state,  int startedAt,  bool vpn,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AndroidRunObservation() when $default != null:
return $default(_that.session,_that.revision,_that.state,_that.startedAt,_that.vpn,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String session,  int revision,  VpnRunState state,  int startedAt,  bool vpn,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _AndroidRunObservation():
return $default(_that.session,_that.revision,_that.state,_that.startedAt,_that.vpn,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String session,  int revision,  VpnRunState state,  int startedAt,  bool vpn,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _AndroidRunObservation() when $default != null:
return $default(_that.session,_that.revision,_that.state,_that.startedAt,_that.vpn,_that.failure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AndroidRunObservation implements AndroidRunObservation {
  const _AndroidRunObservation({required this.session, required this.revision, required this.state, this.startedAt = 0, this.vpn = false, this.failure});
  factory _AndroidRunObservation.fromJson(Map<String, dynamic> json) => _$AndroidRunObservationFromJson(json);

@override final  String session;
@override final  int revision;
@override final  VpnRunState state;
@override@JsonKey() final  int startedAt;
@override@JsonKey() final  bool vpn;
@override final  String? failure;

/// Create a copy of AndroidRunObservation
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AndroidRunObservationCopyWith<_AndroidRunObservation> get copyWith => __$AndroidRunObservationCopyWithImpl<_AndroidRunObservation>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AndroidRunObservationToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AndroidRunObservation&&(identical(other.session, session) || other.session == session)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.state, state) || other.state == state)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.vpn, vpn) || other.vpn == vpn)&&(identical(other.failure, failure) || other.failure == failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,session,revision,state,startedAt,vpn,failure);
}

@override
String toString() {
    return 'AndroidRunObservation(session: $session, revision: $revision, state: $state, startedAt: $startedAt, vpn: $vpn, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$AndroidRunObservationCopyWith<$Res> implements $AndroidRunObservationCopyWith<$Res> {
  factory _$AndroidRunObservationCopyWith(_AndroidRunObservation value, $Res Function(_AndroidRunObservation) _then) = __$AndroidRunObservationCopyWithImpl;
@override @useResult
$Res call({
 String session, int revision, VpnRunState state, int startedAt, bool vpn, String? failure
});




}
/// @nodoc
class __$AndroidRunObservationCopyWithImpl<$Res>
    implements _$AndroidRunObservationCopyWith<$Res> {
  __$AndroidRunObservationCopyWithImpl(this._self, this._then);

  final _AndroidRunObservation _self;
  final $Res Function(_AndroidRunObservation) _then;

/// Create a copy of AndroidRunObservation
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? session = null,Object? revision = null,Object? state = null,Object? startedAt = null,Object? vpn = null,Object? failure = freezed,}) {
  return _then(_AndroidRunObservation(
session: null == session ? _self.session : session // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as VpnRunState,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as int,vpn: null == vpn ? _self.vpn : vpn // ignore: cast_nullable_to_non_nullable
as bool,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$PrepareConfigParams {

 String get generation; int get revision;@JsonKey(includeIfNull: false) bool? get probe;
/// Create a copy of PrepareConfigParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PrepareConfigParamsCopyWith<PrepareConfigParams> get copyWith => _$PrepareConfigParamsCopyWithImpl<PrepareConfigParams>(this as PrepareConfigParams, _$identity);

  /// Serializes this PrepareConfigParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PrepareConfigParams;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PrepareConfigParams&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.probe, _this.probe) || other.probe == _this.probe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PrepareConfigParams;
  return Object.hash(runtimeType,_this.generation,_this.revision,_this.probe);
}

@override
String toString() {
  final _this = this as PrepareConfigParams;
  return 'PrepareConfigParams(generation: ${_this.generation}, revision: ${_this.revision}, probe: ${_this.probe})';
}


}

/// @nodoc
abstract mixin class $PrepareConfigParamsCopyWith<$Res>  {
  factory $PrepareConfigParamsCopyWith(PrepareConfigParams value, $Res Function(PrepareConfigParams) _then) = _$PrepareConfigParamsCopyWithImpl;
@useResult
$Res call({
 String generation, int revision,@JsonKey(includeIfNull: false) bool? probe
});




}
/// @nodoc
class _$PrepareConfigParamsCopyWithImpl<$Res>
    implements $PrepareConfigParamsCopyWith<$Res> {
  _$PrepareConfigParamsCopyWithImpl(this._self, this._then);

  final PrepareConfigParams _self;
  final $Res Function(PrepareConfigParams) _then;

/// Create a copy of PrepareConfigParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? revision = null,Object? probe = freezed,}) {
  return _then(PrepareConfigParams(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,probe: freezed == probe ? _self.probe : probe // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [PrepareConfigParams].
extension PrepareConfigParamsPatterns on PrepareConfigParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PrepareConfigParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PrepareConfigParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PrepareConfigParams value)  $default,){
final _that = this;
switch (_that) {
case _PrepareConfigParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PrepareConfigParams value)?  $default,){
final _that = this;
switch (_that) {
case _PrepareConfigParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String generation,  int revision, @JsonKey(includeIfNull: false)  bool? probe)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PrepareConfigParams() when $default != null:
return $default(_that.generation,_that.revision,_that.probe);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String generation,  int revision, @JsonKey(includeIfNull: false)  bool? probe)  $default,) {final _that = this;
switch (_that) {
case _PrepareConfigParams():
return $default(_that.generation,_that.revision,_that.probe);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String generation,  int revision, @JsonKey(includeIfNull: false)  bool? probe)?  $default,) {final _that = this;
switch (_that) {
case _PrepareConfigParams() when $default != null:
return $default(_that.generation,_that.revision,_that.probe);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PrepareConfigParams implements PrepareConfigParams {
  const _PrepareConfigParams({required this.generation, required this.revision, @JsonKey(includeIfNull: false) this.probe});
  factory _PrepareConfigParams.fromJson(Map<String, dynamic> json) => _$PrepareConfigParamsFromJson(json);

@override final  String generation;
@override final  int revision;
@override@JsonKey(includeIfNull: false) final  bool? probe;

/// Create a copy of PrepareConfigParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PrepareConfigParamsCopyWith<_PrepareConfigParams> get copyWith => __$PrepareConfigParamsCopyWithImpl<_PrepareConfigParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PrepareConfigParamsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PrepareConfigParams&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.probe, probe) || other.probe == probe));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,revision,probe);
}

@override
String toString() {
    return 'PrepareConfigParams(generation: $generation, revision: $revision, probe: $probe)';
}


}

/// @nodoc
abstract mixin class _$PrepareConfigParamsCopyWith<$Res> implements $PrepareConfigParamsCopyWith<$Res> {
  factory _$PrepareConfigParamsCopyWith(_PrepareConfigParams value, $Res Function(_PrepareConfigParams) _then) = __$PrepareConfigParamsCopyWithImpl;
@override @useResult
$Res call({
 String generation, int revision,@JsonKey(includeIfNull: false) bool? probe
});




}
/// @nodoc
class __$PrepareConfigParamsCopyWithImpl<$Res>
    implements _$PrepareConfigParamsCopyWith<$Res> {
  __$PrepareConfigParamsCopyWithImpl(this._self, this._then);

  final _PrepareConfigParams _self;
  final $Res Function(_PrepareConfigParams) _then;

/// Create a copy of PrepareConfigParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? revision = null,Object? probe = freezed,}) {
  return _then(_PrepareConfigParams(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,probe: freezed == probe ? _self.probe : probe // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}


/// @nodoc
mixin _$PreparedConfigResult {

 String get handle; String get generation; int get revision; List<VpnServer> get servers;
/// Create a copy of PreparedConfigResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PreparedConfigResultCopyWith<PreparedConfigResult> get copyWith => _$PreparedConfigResultCopyWithImpl<PreparedConfigResult>(this as PreparedConfigResult, _$identity);

  /// Serializes this PreparedConfigResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PreparedConfigResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PreparedConfigResult&&(identical(other.handle, _this.handle) || other.handle == _this.handle)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&const DeepCollectionEquality().equals(other.servers, _this.servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PreparedConfigResult;
  return Object.hash(runtimeType,_this.handle,_this.generation,_this.revision,const DeepCollectionEquality().hash(_this.servers));
}

@override
String toString() {
  final _this = this as PreparedConfigResult;
  return 'PreparedConfigResult(handle: ${_this.handle}, generation: ${_this.generation}, revision: ${_this.revision}, servers: ${_this.servers})';
}


}

/// @nodoc
abstract mixin class $PreparedConfigResultCopyWith<$Res>  {
  factory $PreparedConfigResultCopyWith(PreparedConfigResult value, $Res Function(PreparedConfigResult) _then) = _$PreparedConfigResultCopyWithImpl;
@useResult
$Res call({
 String handle, String generation, int revision, List<VpnServer> servers
});




}
/// @nodoc
class _$PreparedConfigResultCopyWithImpl<$Res>
    implements $PreparedConfigResultCopyWith<$Res> {
  _$PreparedConfigResultCopyWithImpl(this._self, this._then);

  final PreparedConfigResult _self;
  final $Res Function(PreparedConfigResult) _then;

/// Create a copy of PreparedConfigResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? handle = null,Object? generation = null,Object? revision = null,Object? servers = null,}) {
  return _then(PreparedConfigResult(
handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,
  ));
}

}


/// Adds pattern-matching-related methods to [PreparedConfigResult].
extension PreparedConfigResultPatterns on PreparedConfigResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PreparedConfigResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PreparedConfigResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PreparedConfigResult value)  $default,){
final _that = this;
switch (_that) {
case _PreparedConfigResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PreparedConfigResult value)?  $default,){
final _that = this;
switch (_that) {
case _PreparedConfigResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String handle,  String generation,  int revision,  List<VpnServer> servers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PreparedConfigResult() when $default != null:
return $default(_that.handle,_that.generation,_that.revision,_that.servers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String handle,  String generation,  int revision,  List<VpnServer> servers)  $default,) {final _that = this;
switch (_that) {
case _PreparedConfigResult():
return $default(_that.handle,_that.generation,_that.revision,_that.servers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String handle,  String generation,  int revision,  List<VpnServer> servers)?  $default,) {final _that = this;
switch (_that) {
case _PreparedConfigResult() when $default != null:
return $default(_that.handle,_that.generation,_that.revision,_that.servers);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _PreparedConfigResult implements PreparedConfigResult {
  const _PreparedConfigResult({required this.handle, required this.generation, required this.revision, required  List<VpnServer> servers}): _servers = servers;
  factory _PreparedConfigResult.fromJson(Map<String, dynamic> json) => _$PreparedConfigResultFromJson(json);

@override final  String handle;
@override final  String generation;
@override final  int revision;
 final  List<VpnServer> _servers;
@override List<VpnServer> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}


/// Create a copy of PreparedConfigResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreparedConfigResultCopyWith<_PreparedConfigResult> get copyWith => __$PreparedConfigResultCopyWithImpl<_PreparedConfigResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PreparedConfigResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PreparedConfigResult&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.revision, revision) || other.revision == revision)&&const DeepCollectionEquality().equals(other.servers, _servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,handle,generation,revision,const DeepCollectionEquality().hash(_servers));
}

@override
String toString() {
    return 'PreparedConfigResult(handle: $handle, generation: $generation, revision: $revision, servers: $servers)';
}


}

/// @nodoc
abstract mixin class _$PreparedConfigResultCopyWith<$Res> implements $PreparedConfigResultCopyWith<$Res> {
  factory _$PreparedConfigResultCopyWith(_PreparedConfigResult value, $Res Function(_PreparedConfigResult) _then) = __$PreparedConfigResultCopyWithImpl;
@override @useResult
$Res call({
 String handle, String generation, int revision, List<VpnServer> servers
});




}
/// @nodoc
class __$PreparedConfigResultCopyWithImpl<$Res>
    implements _$PreparedConfigResultCopyWith<$Res> {
  __$PreparedConfigResultCopyWithImpl(this._self, this._then);

  final _PreparedConfigResult _self;
  final $Res Function(_PreparedConfigResult) _then;

/// Create a copy of PreparedConfigResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? handle = null,Object? generation = null,Object? revision = null,Object? servers = null,}) {
  return _then(_PreparedConfigResult(
handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,
  ));
}


}


/// @nodoc
mixin _$PreparedConfigRef {

 String get handle; int get revision;
/// Create a copy of PreparedConfigRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PreparedConfigRefCopyWith<PreparedConfigRef> get copyWith => _$PreparedConfigRefCopyWithImpl<PreparedConfigRef>(this as PreparedConfigRef, _$identity);

  /// Serializes this PreparedConfigRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as PreparedConfigRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PreparedConfigRef&&(identical(other.handle, _this.handle) || other.handle == _this.handle)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as PreparedConfigRef;
  return Object.hash(runtimeType,_this.handle,_this.revision);
}

@override
String toString() {
  final _this = this as PreparedConfigRef;
  return 'PreparedConfigRef(handle: ${_this.handle}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $PreparedConfigRefCopyWith<$Res>  {
  factory $PreparedConfigRefCopyWith(PreparedConfigRef value, $Res Function(PreparedConfigRef) _then) = _$PreparedConfigRefCopyWithImpl;
@useResult
$Res call({
 String handle, int revision
});




}
/// @nodoc
class _$PreparedConfigRefCopyWithImpl<$Res>
    implements $PreparedConfigRefCopyWith<$Res> {
  _$PreparedConfigRefCopyWithImpl(this._self, this._then);

  final PreparedConfigRef _self;
  final $Res Function(PreparedConfigRef) _then;

/// Create a copy of PreparedConfigRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? handle = null,Object? revision = null,}) {
  return _then(PreparedConfigRef(
handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PreparedConfigRef].
extension PreparedConfigRefPatterns on PreparedConfigRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PreparedConfigRef value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PreparedConfigRef() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PreparedConfigRef value)  $default,){
final _that = this;
switch (_that) {
case _PreparedConfigRef():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PreparedConfigRef value)?  $default,){
final _that = this;
switch (_that) {
case _PreparedConfigRef() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String handle,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PreparedConfigRef() when $default != null:
return $default(_that.handle,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String handle,  int revision)  $default,) {final _that = this;
switch (_that) {
case _PreparedConfigRef():
return $default(_that.handle,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String handle,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _PreparedConfigRef() when $default != null:
return $default(_that.handle,_that.revision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PreparedConfigRef implements PreparedConfigRef {
  const _PreparedConfigRef({required this.handle, required this.revision});
  factory _PreparedConfigRef.fromJson(Map<String, dynamic> json) => _$PreparedConfigRefFromJson(json);

@override final  String handle;
@override final  int revision;

/// Create a copy of PreparedConfigRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PreparedConfigRefCopyWith<_PreparedConfigRef> get copyWith => __$PreparedConfigRefCopyWithImpl<_PreparedConfigRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PreparedConfigRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PreparedConfigRef&&(identical(other.handle, handle) || other.handle == handle)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,handle,revision);
}

@override
String toString() {
    return 'PreparedConfigRef(handle: $handle, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$PreparedConfigRefCopyWith<$Res> implements $PreparedConfigRefCopyWith<$Res> {
  factory _$PreparedConfigRefCopyWith(_PreparedConfigRef value, $Res Function(_PreparedConfigRef) _then) = __$PreparedConfigRefCopyWithImpl;
@override @useResult
$Res call({
 String handle, int revision
});




}
/// @nodoc
class __$PreparedConfigRefCopyWithImpl<$Res>
    implements _$PreparedConfigRefCopyWith<$Res> {
  __$PreparedConfigRefCopyWithImpl(this._self, this._then);

  final _PreparedConfigRef _self;
  final $Res Function(_PreparedConfigRef) _then;

/// Create a copy of PreparedConfigRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? handle = null,Object? revision = null,}) {
  return _then(_PreparedConfigRef(
handle: null == handle ? _self.handle : handle // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$ActivateConfigParams {

 PreparedConfigRef get prepared; SetupParams get setup;
/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivateConfigParamsCopyWith<ActivateConfigParams> get copyWith => _$ActivateConfigParamsCopyWithImpl<ActivateConfigParams>(this as ActivateConfigParams, _$identity);

  /// Serializes this ActivateConfigParams to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ActivateConfigParams;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivateConfigParams&&(identical(other.prepared, _this.prepared) || other.prepared == _this.prepared)&&(identical(other.setup, _this.setup) || other.setup == _this.setup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ActivateConfigParams;
  return Object.hash(runtimeType,_this.prepared,_this.setup);
}

@override
String toString() {
  final _this = this as ActivateConfigParams;
  return 'ActivateConfigParams(prepared: ${_this.prepared}, setup: ${_this.setup})';
}


}

/// @nodoc
abstract mixin class $ActivateConfigParamsCopyWith<$Res>  {
  factory $ActivateConfigParamsCopyWith(ActivateConfigParams value, $Res Function(ActivateConfigParams) _then) = _$ActivateConfigParamsCopyWithImpl;
@useResult
$Res call({
 PreparedConfigRef prepared, SetupParams setup
});


$PreparedConfigRefCopyWith<$Res> get prepared;$SetupParamsCopyWith<$Res> get setup;

}
/// @nodoc
class _$ActivateConfigParamsCopyWithImpl<$Res>
    implements $ActivateConfigParamsCopyWith<$Res> {
  _$ActivateConfigParamsCopyWithImpl(this._self, this._then);

  final ActivateConfigParams _self;
  final $Res Function(ActivateConfigParams) _then;

/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? prepared = null,Object? setup = null,}) {
  return _then(ActivateConfigParams(
prepared: null == prepared ? _self.prepared : prepared // ignore: cast_nullable_to_non_nullable
as PreparedConfigRef,setup: null == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as SetupParams,
  ));
}
/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PreparedConfigRefCopyWith<$Res> get prepared {
  
  return $PreparedConfigRefCopyWith<$Res>(_self.prepared, (value) {
    return _then(_self.copyWith(prepared: value));
  });
}/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SetupParamsCopyWith<$Res> get setup {
  
  return $SetupParamsCopyWith<$Res>(_self.setup, (value) {
    return _then(_self.copyWith(setup: value));
  });
}
}


/// Adds pattern-matching-related methods to [ActivateConfigParams].
extension ActivateConfigParamsPatterns on ActivateConfigParams {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivateConfigParams value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivateConfigParams() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivateConfigParams value)  $default,){
final _that = this;
switch (_that) {
case _ActivateConfigParams():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivateConfigParams value)?  $default,){
final _that = this;
switch (_that) {
case _ActivateConfigParams() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PreparedConfigRef prepared,  SetupParams setup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivateConfigParams() when $default != null:
return $default(_that.prepared,_that.setup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PreparedConfigRef prepared,  SetupParams setup)  $default,) {final _that = this;
switch (_that) {
case _ActivateConfigParams():
return $default(_that.prepared,_that.setup);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PreparedConfigRef prepared,  SetupParams setup)?  $default,) {final _that = this;
switch (_that) {
case _ActivateConfigParams() when $default != null:
return $default(_that.prepared,_that.setup);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class _ActivateConfigParams implements ActivateConfigParams {
  const _ActivateConfigParams({required this.prepared, required this.setup});
  factory _ActivateConfigParams.fromJson(Map<String, dynamic> json) => _$ActivateConfigParamsFromJson(json);

@override final  PreparedConfigRef prepared;
@override final  SetupParams setup;

/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivateConfigParamsCopyWith<_ActivateConfigParams> get copyWith => __$ActivateConfigParamsCopyWithImpl<_ActivateConfigParams>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivateConfigParamsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivateConfigParams&&(identical(other.prepared, prepared) || other.prepared == prepared)&&(identical(other.setup, setup) || other.setup == setup));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,prepared,setup);
}

@override
String toString() {
    return 'ActivateConfigParams(prepared: $prepared, setup: $setup)';
}


}

/// @nodoc
abstract mixin class _$ActivateConfigParamsCopyWith<$Res> implements $ActivateConfigParamsCopyWith<$Res> {
  factory _$ActivateConfigParamsCopyWith(_ActivateConfigParams value, $Res Function(_ActivateConfigParams) _then) = __$ActivateConfigParamsCopyWithImpl;
@override @useResult
$Res call({
 PreparedConfigRef prepared, SetupParams setup
});


@override $PreparedConfigRefCopyWith<$Res> get prepared;@override $SetupParamsCopyWith<$Res> get setup;

}
/// @nodoc
class __$ActivateConfigParamsCopyWithImpl<$Res>
    implements _$ActivateConfigParamsCopyWith<$Res> {
  __$ActivateConfigParamsCopyWithImpl(this._self, this._then);

  final _ActivateConfigParams _self;
  final $Res Function(_ActivateConfigParams) _then;

/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? prepared = null,Object? setup = null,}) {
  return _then(_ActivateConfigParams(
prepared: null == prepared ? _self.prepared : prepared // ignore: cast_nullable_to_non_nullable
as PreparedConfigRef,setup: null == setup ? _self.setup : setup // ignore: cast_nullable_to_non_nullable
as SetupParams,
  ));
}

/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PreparedConfigRefCopyWith<$Res> get prepared {
  
  return $PreparedConfigRefCopyWith<$Res>(_self.prepared, (value) {
    return _then(_self.copyWith(prepared: value));
  });
}/// Create a copy of ActivateConfigParams
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SetupParamsCopyWith<$Res> get setup {
  
  return $SetupParamsCopyWith<$Res>(_self.setup, (value) {
    return _then(_self.copyWith(setup: value));
  });
}
}


/// @nodoc
mixin _$ActivatedConfigResult {

 String get generation; int get revision;
/// Create a copy of ActivatedConfigResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivatedConfigResultCopyWith<ActivatedConfigResult> get copyWith => _$ActivatedConfigResultCopyWithImpl<ActivatedConfigResult>(this as ActivatedConfigResult, _$identity);

  /// Serializes this ActivatedConfigResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ActivatedConfigResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivatedConfigResult&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.revision, _this.revision) || other.revision == _this.revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ActivatedConfigResult;
  return Object.hash(runtimeType,_this.generation,_this.revision);
}

@override
String toString() {
  final _this = this as ActivatedConfigResult;
  return 'ActivatedConfigResult(generation: ${_this.generation}, revision: ${_this.revision})';
}


}

/// @nodoc
abstract mixin class $ActivatedConfigResultCopyWith<$Res>  {
  factory $ActivatedConfigResultCopyWith(ActivatedConfigResult value, $Res Function(ActivatedConfigResult) _then) = _$ActivatedConfigResultCopyWithImpl;
@useResult
$Res call({
 String generation, int revision
});




}
/// @nodoc
class _$ActivatedConfigResultCopyWithImpl<$Res>
    implements $ActivatedConfigResultCopyWith<$Res> {
  _$ActivatedConfigResultCopyWithImpl(this._self, this._then);

  final ActivatedConfigResult _self;
  final $Res Function(ActivatedConfigResult) _then;

/// Create a copy of ActivatedConfigResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? generation = null,Object? revision = null,}) {
  return _then(ActivatedConfigResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivatedConfigResult].
extension ActivatedConfigResultPatterns on ActivatedConfigResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivatedConfigResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivatedConfigResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivatedConfigResult value)  $default,){
final _that = this;
switch (_that) {
case _ActivatedConfigResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivatedConfigResult value)?  $default,){
final _that = this;
switch (_that) {
case _ActivatedConfigResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String generation,  int revision)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivatedConfigResult() when $default != null:
return $default(_that.generation,_that.revision);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String generation,  int revision)  $default,) {final _that = this;
switch (_that) {
case _ActivatedConfigResult():
return $default(_that.generation,_that.revision);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String generation,  int revision)?  $default,) {final _that = this;
switch (_that) {
case _ActivatedConfigResult() when $default != null:
return $default(_that.generation,_that.revision);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ActivatedConfigResult implements ActivatedConfigResult {
  const _ActivatedConfigResult({required this.generation, required this.revision});
  factory _ActivatedConfigResult.fromJson(Map<String, dynamic> json) => _$ActivatedConfigResultFromJson(json);

@override final  String generation;
@override final  int revision;

/// Create a copy of ActivatedConfigResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivatedConfigResultCopyWith<_ActivatedConfigResult> get copyWith => __$ActivatedConfigResultCopyWithImpl<_ActivatedConfigResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ActivatedConfigResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivatedConfigResult&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.revision, revision) || other.revision == revision));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,generation,revision);
}

@override
String toString() {
    return 'ActivatedConfigResult(generation: $generation, revision: $revision)';
}


}

/// @nodoc
abstract mixin class _$ActivatedConfigResultCopyWith<$Res> implements $ActivatedConfigResultCopyWith<$Res> {
  factory _$ActivatedConfigResultCopyWith(_ActivatedConfigResult value, $Res Function(_ActivatedConfigResult) _then) = __$ActivatedConfigResultCopyWithImpl;
@override @useResult
$Res call({
 String generation, int revision
});




}
/// @nodoc
class __$ActivatedConfigResultCopyWithImpl<$Res>
    implements _$ActivatedConfigResultCopyWith<$Res> {
  __$ActivatedConfigResultCopyWithImpl(this._self, this._then);

  final _ActivatedConfigResult _self;
  final $Res Function(_ActivatedConfigResult) _then;

/// Create a copy of ActivatedConfigResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? generation = null,Object? revision = null,}) {
  return _then(_ActivatedConfigResult(
generation: null == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String,revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

VpnSelection _$VpnSelectionFromJson(
  Map<String, dynamic> json
) {
        switch (json['kind']) {
                  case 'auto':
          return VpnAutoSelection.fromJson(
            json
          );
                case 'fallback':
          return VpnFallbackSelection.fromJson(
            json
          );
                case 'server':
          return VpnServerSelection.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'kind',
  'VpnSelection',
  'Invalid union type "${json['kind']}"!'
);
        }
      
}

/// @nodoc
mixin _$VpnSelection {



  /// Serializes this VpnSelection to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnSelection);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'VpnSelection()';
}


}

/// @nodoc
class $VpnSelectionCopyWith<$Res>  {
$VpnSelectionCopyWith(VpnSelection _, $Res Function(VpnSelection) __);
}


/// Adds pattern-matching-related methods to [VpnSelection].
extension VpnSelectionPatterns on VpnSelection {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( VpnAutoSelection value)?  auto,TResult Function( VpnFallbackSelection value)?  fallback,TResult Function( VpnServerSelection value)?  server,required TResult orElse(),}){
final _that = this;
switch (_that) {
case VpnAutoSelection() when auto != null:
return auto(_that);case VpnFallbackSelection() when fallback != null:
return fallback(_that);case VpnServerSelection() when server != null:
return server(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( VpnAutoSelection value)  auto,required TResult Function( VpnFallbackSelection value)  fallback,required TResult Function( VpnServerSelection value)  server,}){
final _that = this;
switch (_that) {
case VpnAutoSelection():
return auto(_that);case VpnFallbackSelection():
return fallback(_that);case VpnServerSelection():
return server(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( VpnAutoSelection value)?  auto,TResult? Function( VpnFallbackSelection value)?  fallback,TResult? Function( VpnServerSelection value)?  server,}){
final _that = this;
switch (_that) {
case VpnAutoSelection() when auto != null:
return auto(_that);case VpnFallbackSelection() when fallback != null:
return fallback(_that);case VpnServerSelection() when server != null:
return server(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  auto,TResult Function()?  fallback,TResult Function( String id)?  server,required TResult orElse(),}) {final _that = this;
switch (_that) {
case VpnAutoSelection() when auto != null:
return auto();case VpnFallbackSelection() when fallback != null:
return fallback();case VpnServerSelection() when server != null:
return server(_that.id);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  auto,required TResult Function()  fallback,required TResult Function( String id)  server,}) {final _that = this;
switch (_that) {
case VpnAutoSelection():
return auto();case VpnFallbackSelection():
return fallback();case VpnServerSelection():
return server(_that.id);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  auto,TResult? Function()?  fallback,TResult? Function( String id)?  server,}) {final _that = this;
switch (_that) {
case VpnAutoSelection() when auto != null:
return auto();case VpnFallbackSelection() when fallback != null:
return fallback();case VpnServerSelection() when server != null:
return server(_that.id);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class VpnAutoSelection implements VpnSelection {
  const VpnAutoSelection({ String? $type}): $type = $type ?? 'auto';
  factory VpnAutoSelection.fromJson(Map<String, dynamic> json) => _$VpnAutoSelectionFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$VpnAutoSelectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnAutoSelection);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'VpnSelection.auto()';
}


}




/// @nodoc
@JsonSerializable()

class VpnFallbackSelection implements VpnSelection {
  const VpnFallbackSelection({ String? $type}): $type = $type ?? 'fallback';
  factory VpnFallbackSelection.fromJson(Map<String, dynamic> json) => _$VpnFallbackSelectionFromJson(json);



@JsonKey(name: 'kind')
final String $type;



@override
Map<String, dynamic> toJson() {
  return _$VpnFallbackSelectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnFallbackSelection);
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'VpnSelection.fallback()';
}


}




/// @nodoc
@JsonSerializable()

class VpnServerSelection implements VpnSelection {
  const VpnServerSelection(this.id, { String? $type}): $type = $type ?? 'server';
  factory VpnServerSelection.fromJson(Map<String, dynamic> json) => _$VpnServerSelectionFromJson(json);

 final  String id;

@JsonKey(name: 'kind')
final String $type;


/// Create a copy of VpnSelection
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnServerSelectionCopyWith<VpnServerSelection> get copyWith => _$VpnServerSelectionCopyWithImpl<VpnServerSelection>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnServerSelectionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnServerSelection&&(identical(other.id, id) || other.id == id));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id);
}

@override
String toString() {
    return 'VpnSelection.server(id: $id)';
}


}

/// @nodoc
abstract mixin class $VpnServerSelectionCopyWith<$Res> implements $VpnSelectionCopyWith<$Res> {
  factory $VpnServerSelectionCopyWith(VpnServerSelection value, $Res Function(VpnServerSelection) _then) = _$VpnServerSelectionCopyWithImpl;
@useResult
$Res call({
 String id
});




}
/// @nodoc
class _$VpnServerSelectionCopyWithImpl<$Res>
    implements $VpnServerSelectionCopyWith<$Res> {
  _$VpnServerSelectionCopyWithImpl(this._self, this._then);

  final VpnServerSelection _self;
  final $Res Function(VpnServerSelection) _then;

/// Create a copy of VpnSelection
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? id = null,}) {
  return _then(VpnServerSelection(
null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$VpnServer {

 String get id; String get name; String get target; String get type; String? get provider;
/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnServerCopyWith<VpnServer> get copyWith => _$VpnServerCopyWithImpl<VpnServer>(this as VpnServer, _$identity);

  /// Serializes this VpnServer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VpnServer;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnServer&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.provider, _this.provider) || other.provider == _this.provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VpnServer;
  return Object.hash(runtimeType,_this.id,_this.name,_this.target,_this.type,_this.provider);
}

@override
String toString() {
  final _this = this as VpnServer;
  return 'VpnServer(id: ${_this.id}, name: ${_this.name}, target: ${_this.target}, type: ${_this.type}, provider: ${_this.provider})';
}


}

/// @nodoc
abstract mixin class $VpnServerCopyWith<$Res>  {
  factory $VpnServerCopyWith(VpnServer value, $Res Function(VpnServer) _then) = _$VpnServerCopyWithImpl;
@useResult
$Res call({
 String id, String name, String target, String type, String? provider
});




}
/// @nodoc
class _$VpnServerCopyWithImpl<$Res>
    implements $VpnServerCopyWith<$Res> {
  _$VpnServerCopyWithImpl(this._self, this._then);

  final VpnServer _self;
  final $Res Function(VpnServer) _then;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? target = null,Object? type = null,Object? provider = freezed,}) {
  return _then(VpnServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VpnServer].
extension VpnServerPatterns on VpnServer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnServer value)  $default,){
final _that = this;
switch (_that) {
case _VpnServer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnServer value)?  $default,){
final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String target,  String type,  String? provider)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
return $default(_that.id,_that.name,_that.target,_that.type,_that.provider);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String target,  String type,  String? provider)  $default,) {final _that = this;
switch (_that) {
case _VpnServer():
return $default(_that.id,_that.name,_that.target,_that.type,_that.provider);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String target,  String type,  String? provider)?  $default,) {final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
return $default(_that.id,_that.name,_that.target,_that.type,_that.provider);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnServer implements VpnServer {
  const _VpnServer({required this.id, required this.name, required this.target, required this.type, this.provider});
  factory _VpnServer.fromJson(Map<String, dynamic> json) => _$VpnServerFromJson(json);

@override final  String id;
@override final  String name;
@override final  String target;
@override final  String type;
@override final  String? provider;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnServerCopyWith<_VpnServer> get copyWith => __$VpnServerCopyWithImpl<_VpnServer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnServerToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnServer&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.target, target) || other.target == target)&&(identical(other.type, type) || other.type == type)&&(identical(other.provider, provider) || other.provider == provider));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,target,type,provider);
}

@override
String toString() {
    return 'VpnServer(id: $id, name: $name, target: $target, type: $type, provider: $provider)';
}


}

/// @nodoc
abstract mixin class _$VpnServerCopyWith<$Res> implements $VpnServerCopyWith<$Res> {
  factory _$VpnServerCopyWith(_VpnServer value, $Res Function(_VpnServer) _then) = __$VpnServerCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String target, String type, String? provider
});




}
/// @nodoc
class __$VpnServerCopyWithImpl<$Res>
    implements _$VpnServerCopyWith<$Res> {
  __$VpnServerCopyWithImpl(this._self, this._then);

  final _VpnServer _self;
  final $Res Function(_VpnServer) _then;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? target = null,Object? type = null,Object? provider = freezed,}) {
  return _then(_VpnServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,provider: freezed == provider ? _self.provider : provider // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$ProfileSnapshot {

 int get revision; String? get generation; VpnRoutingMode get routing; VpnSelection get selection; Mode get advancedMode; List<VpnServer> get servers; List<VpnProviderRefresh> get providerRefresh; VpnManagedGroups? get managedGroups;
/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProfileSnapshotCopyWith<ProfileSnapshot> get copyWith => _$ProfileSnapshotCopyWithImpl<ProfileSnapshot>(this as ProfileSnapshot, _$identity);

  /// Serializes this ProfileSnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProfileSnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProfileSnapshot&&(identical(other.revision, _this.revision) || other.revision == _this.revision)&&(identical(other.generation, _this.generation) || other.generation == _this.generation)&&(identical(other.routing, _this.routing) || other.routing == _this.routing)&&(identical(other.selection, _this.selection) || other.selection == _this.selection)&&(identical(other.advancedMode, _this.advancedMode) || other.advancedMode == _this.advancedMode)&&const DeepCollectionEquality().equals(other.servers, _this.servers)&&const DeepCollectionEquality().equals(other.providerRefresh, _this.providerRefresh)&&(identical(other.managedGroups, _this.managedGroups) || other.managedGroups == _this.managedGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProfileSnapshot;
  return Object.hash(runtimeType,_this.revision,_this.generation,_this.routing,_this.selection,_this.advancedMode,const DeepCollectionEquality().hash(_this.servers),const DeepCollectionEquality().hash(_this.providerRefresh),_this.managedGroups);
}

@override
String toString() {
  final _this = this as ProfileSnapshot;
  return 'ProfileSnapshot(revision: ${_this.revision}, generation: ${_this.generation}, routing: ${_this.routing}, selection: ${_this.selection}, advancedMode: ${_this.advancedMode}, servers: ${_this.servers}, providerRefresh: ${_this.providerRefresh}, managedGroups: ${_this.managedGroups})';
}


}

/// @nodoc
abstract mixin class $ProfileSnapshotCopyWith<$Res>  {
  factory $ProfileSnapshotCopyWith(ProfileSnapshot value, $Res Function(ProfileSnapshot) _then) = _$ProfileSnapshotCopyWithImpl;
@useResult
$Res call({
 int revision, String? generation, VpnRoutingMode routing, VpnSelection selection, Mode advancedMode, List<VpnServer> servers, List<VpnProviderRefresh> providerRefresh, VpnManagedGroups? managedGroups
});


$VpnSelectionCopyWith<$Res> get selection;$VpnManagedGroupsCopyWith<$Res>? get managedGroups;

}
/// @nodoc
class _$ProfileSnapshotCopyWithImpl<$Res>
    implements $ProfileSnapshotCopyWith<$Res> {
  _$ProfileSnapshotCopyWithImpl(this._self, this._then);

  final ProfileSnapshot _self;
  final $Res Function(ProfileSnapshot) _then;

/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? revision = null,Object? generation = freezed,Object? routing = null,Object? selection = null,Object? advancedMode = null,Object? servers = null,Object? providerRefresh = null,Object? managedGroups = freezed,}) {
  return _then(ProfileSnapshot(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,generation: freezed == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String?,routing: null == routing ? _self.routing : routing // ignore: cast_nullable_to_non_nullable
as VpnRoutingMode,selection: null == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as VpnSelection,advancedMode: null == advancedMode ? _self.advancedMode : advancedMode // ignore: cast_nullable_to_non_nullable
as Mode,servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,providerRefresh: null == providerRefresh ? _self.providerRefresh : providerRefresh // ignore: cast_nullable_to_non_nullable
as List<VpnProviderRefresh>,managedGroups: freezed == managedGroups ? _self.managedGroups : managedGroups // ignore: cast_nullable_to_non_nullable
as VpnManagedGroups?,
  ));
}
/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnSelectionCopyWith<$Res> get selection {
  
  return $VpnSelectionCopyWith<$Res>(_self.selection, (value) {
    return _then(_self.copyWith(selection: value));
  });
}/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnManagedGroupsCopyWith<$Res>? get managedGroups {
    if (_self.managedGroups == null) {
    return null;
  }

  return $VpnManagedGroupsCopyWith<$Res>(_self.managedGroups!, (value) {
    return _then(_self.copyWith(managedGroups: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProfileSnapshot].
extension ProfileSnapshotPatterns on ProfileSnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProfileSnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProfileSnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProfileSnapshot value)  $default,){
final _that = this;
switch (_that) {
case _ProfileSnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProfileSnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _ProfileSnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int revision,  String? generation,  VpnRoutingMode routing,  VpnSelection selection,  Mode advancedMode,  List<VpnServer> servers,  List<VpnProviderRefresh> providerRefresh,  VpnManagedGroups? managedGroups)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProfileSnapshot() when $default != null:
return $default(_that.revision,_that.generation,_that.routing,_that.selection,_that.advancedMode,_that.servers,_that.providerRefresh,_that.managedGroups);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int revision,  String? generation,  VpnRoutingMode routing,  VpnSelection selection,  Mode advancedMode,  List<VpnServer> servers,  List<VpnProviderRefresh> providerRefresh,  VpnManagedGroups? managedGroups)  $default,) {final _that = this;
switch (_that) {
case _ProfileSnapshot():
return $default(_that.revision,_that.generation,_that.routing,_that.selection,_that.advancedMode,_that.servers,_that.providerRefresh,_that.managedGroups);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int revision,  String? generation,  VpnRoutingMode routing,  VpnSelection selection,  Mode advancedMode,  List<VpnServer> servers,  List<VpnProviderRefresh> providerRefresh,  VpnManagedGroups? managedGroups)?  $default,) {final _that = this;
switch (_that) {
case _ProfileSnapshot() when $default != null:
return $default(_that.revision,_that.generation,_that.routing,_that.selection,_that.advancedMode,_that.servers,_that.providerRefresh,_that.managedGroups);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProfileSnapshot implements ProfileSnapshot {
  const _ProfileSnapshot({this.revision = 0, this.generation, this.routing = VpnRoutingMode.simple, this.selection = const VpnSelection.auto(), this.advancedMode = Mode.rule,  List<VpnServer> servers = const [],  List<VpnProviderRefresh> providerRefresh = const [], this.managedGroups}): _servers = servers,_providerRefresh = providerRefresh;
  factory _ProfileSnapshot.fromJson(Map<String, dynamic> json) => _$ProfileSnapshotFromJson(json);

@override@JsonKey() final  int revision;
@override final  String? generation;
@override@JsonKey() final  VpnRoutingMode routing;
@override@JsonKey() final  VpnSelection selection;
@override@JsonKey() final  Mode advancedMode;
 final  List<VpnServer> _servers;
@override@JsonKey() List<VpnServer> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}

 final  List<VpnProviderRefresh> _providerRefresh;
@override@JsonKey() List<VpnProviderRefresh> get providerRefresh {
  if (_providerRefresh is EqualUnmodifiableListView) return _providerRefresh;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_providerRefresh);
}

@override final  VpnManagedGroups? managedGroups;

/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProfileSnapshotCopyWith<_ProfileSnapshot> get copyWith => __$ProfileSnapshotCopyWithImpl<_ProfileSnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProfileSnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProfileSnapshot&&(identical(other.revision, revision) || other.revision == revision)&&(identical(other.generation, generation) || other.generation == generation)&&(identical(other.routing, routing) || other.routing == routing)&&(identical(other.selection, selection) || other.selection == selection)&&(identical(other.advancedMode, advancedMode) || other.advancedMode == advancedMode)&&const DeepCollectionEquality().equals(other.servers, _servers)&&const DeepCollectionEquality().equals(other.providerRefresh, _providerRefresh)&&(identical(other.managedGroups, managedGroups) || other.managedGroups == managedGroups));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,revision,generation,routing,selection,advancedMode,const DeepCollectionEquality().hash(_servers),const DeepCollectionEquality().hash(_providerRefresh),managedGroups);
}

@override
String toString() {
    return 'ProfileSnapshot(revision: $revision, generation: $generation, routing: $routing, selection: $selection, advancedMode: $advancedMode, servers: $servers, providerRefresh: $providerRefresh, managedGroups: $managedGroups)';
}


}

/// @nodoc
abstract mixin class _$ProfileSnapshotCopyWith<$Res> implements $ProfileSnapshotCopyWith<$Res> {
  factory _$ProfileSnapshotCopyWith(_ProfileSnapshot value, $Res Function(_ProfileSnapshot) _then) = __$ProfileSnapshotCopyWithImpl;
@override @useResult
$Res call({
 int revision, String? generation, VpnRoutingMode routing, VpnSelection selection, Mode advancedMode, List<VpnServer> servers, List<VpnProviderRefresh> providerRefresh, VpnManagedGroups? managedGroups
});


@override $VpnSelectionCopyWith<$Res> get selection;@override $VpnManagedGroupsCopyWith<$Res>? get managedGroups;

}
/// @nodoc
class __$ProfileSnapshotCopyWithImpl<$Res>
    implements _$ProfileSnapshotCopyWith<$Res> {
  __$ProfileSnapshotCopyWithImpl(this._self, this._then);

  final _ProfileSnapshot _self;
  final $Res Function(_ProfileSnapshot) _then;

/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? revision = null,Object? generation = freezed,Object? routing = null,Object? selection = null,Object? advancedMode = null,Object? servers = null,Object? providerRefresh = null,Object? managedGroups = freezed,}) {
  return _then(_ProfileSnapshot(
revision: null == revision ? _self.revision : revision // ignore: cast_nullable_to_non_nullable
as int,generation: freezed == generation ? _self.generation : generation // ignore: cast_nullable_to_non_nullable
as String?,routing: null == routing ? _self.routing : routing // ignore: cast_nullable_to_non_nullable
as VpnRoutingMode,selection: null == selection ? _self.selection : selection // ignore: cast_nullable_to_non_nullable
as VpnSelection,advancedMode: null == advancedMode ? _self.advancedMode : advancedMode // ignore: cast_nullable_to_non_nullable
as Mode,servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,providerRefresh: null == providerRefresh ? _self._providerRefresh : providerRefresh // ignore: cast_nullable_to_non_nullable
as List<VpnProviderRefresh>,managedGroups: freezed == managedGroups ? _self.managedGroups : managedGroups // ignore: cast_nullable_to_non_nullable
as VpnManagedGroups?,
  ));
}

/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnSelectionCopyWith<$Res> get selection {
  
  return $VpnSelectionCopyWith<$Res>(_self.selection, (value) {
    return _then(_self.copyWith(selection: value));
  });
}/// Create a copy of ProfileSnapshot
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VpnManagedGroupsCopyWith<$Res>? get managedGroups {
    if (_self.managedGroups == null) {
    return null;
  }

  return $VpnManagedGroupsCopyWith<$Res>(_self.managedGroups!, (value) {
    return _then(_self.copyWith(managedGroups: value));
  });
}
}


/// @nodoc
mixin _$VpnProviderRefresh {

 String get section; String get name; int get interval; DateTime? get lastUpdate;
/// Create a copy of VpnProviderRefresh
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnProviderRefreshCopyWith<VpnProviderRefresh> get copyWith => _$VpnProviderRefreshCopyWithImpl<VpnProviderRefresh>(this as VpnProviderRefresh, _$identity);

  /// Serializes this VpnProviderRefresh to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VpnProviderRefresh;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnProviderRefresh&&(identical(other.section, _this.section) || other.section == _this.section)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.interval, _this.interval) || other.interval == _this.interval)&&(identical(other.lastUpdate, _this.lastUpdate) || other.lastUpdate == _this.lastUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VpnProviderRefresh;
  return Object.hash(runtimeType,_this.section,_this.name,_this.interval,_this.lastUpdate);
}

@override
String toString() {
  final _this = this as VpnProviderRefresh;
  return 'VpnProviderRefresh(section: ${_this.section}, name: ${_this.name}, interval: ${_this.interval}, lastUpdate: ${_this.lastUpdate})';
}


}

/// @nodoc
abstract mixin class $VpnProviderRefreshCopyWith<$Res>  {
  factory $VpnProviderRefreshCopyWith(VpnProviderRefresh value, $Res Function(VpnProviderRefresh) _then) = _$VpnProviderRefreshCopyWithImpl;
@useResult
$Res call({
 String section, String name, int interval, DateTime? lastUpdate
});




}
/// @nodoc
class _$VpnProviderRefreshCopyWithImpl<$Res>
    implements $VpnProviderRefreshCopyWith<$Res> {
  _$VpnProviderRefreshCopyWithImpl(this._self, this._then);

  final VpnProviderRefresh _self;
  final $Res Function(VpnProviderRefresh) _then;

/// Create a copy of VpnProviderRefresh
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? section = null,Object? name = null,Object? interval = null,Object? lastUpdate = freezed,}) {
  return _then(VpnProviderRefresh(
section: null == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,interval: null == interval ? _self.interval : interval // ignore: cast_nullable_to_non_nullable
as int,lastUpdate: freezed == lastUpdate ? _self.lastUpdate : lastUpdate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VpnProviderRefresh].
extension VpnProviderRefreshPatterns on VpnProviderRefresh {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnProviderRefresh value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnProviderRefresh() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnProviderRefresh value)  $default,){
final _that = this;
switch (_that) {
case _VpnProviderRefresh():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnProviderRefresh value)?  $default,){
final _that = this;
switch (_that) {
case _VpnProviderRefresh() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String section,  String name,  int interval,  DateTime? lastUpdate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnProviderRefresh() when $default != null:
return $default(_that.section,_that.name,_that.interval,_that.lastUpdate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String section,  String name,  int interval,  DateTime? lastUpdate)  $default,) {final _that = this;
switch (_that) {
case _VpnProviderRefresh():
return $default(_that.section,_that.name,_that.interval,_that.lastUpdate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String section,  String name,  int interval,  DateTime? lastUpdate)?  $default,) {final _that = this;
switch (_that) {
case _VpnProviderRefresh() when $default != null:
return $default(_that.section,_that.name,_that.interval,_that.lastUpdate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnProviderRefresh implements VpnProviderRefresh {
  const _VpnProviderRefresh({required this.section, required this.name, required this.interval, this.lastUpdate});
  factory _VpnProviderRefresh.fromJson(Map<String, dynamic> json) => _$VpnProviderRefreshFromJson(json);

@override final  String section;
@override final  String name;
@override final  int interval;
@override final  DateTime? lastUpdate;

/// Create a copy of VpnProviderRefresh
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnProviderRefreshCopyWith<_VpnProviderRefresh> get copyWith => __$VpnProviderRefreshCopyWithImpl<_VpnProviderRefresh>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnProviderRefreshToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnProviderRefresh&&(identical(other.section, section) || other.section == section)&&(identical(other.name, name) || other.name == name)&&(identical(other.interval, interval) || other.interval == interval)&&(identical(other.lastUpdate, lastUpdate) || other.lastUpdate == lastUpdate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,section,name,interval,lastUpdate);
}

@override
String toString() {
    return 'VpnProviderRefresh(section: $section, name: $name, interval: $interval, lastUpdate: $lastUpdate)';
}


}

/// @nodoc
abstract mixin class _$VpnProviderRefreshCopyWith<$Res> implements $VpnProviderRefreshCopyWith<$Res> {
  factory _$VpnProviderRefreshCopyWith(_VpnProviderRefresh value, $Res Function(_VpnProviderRefresh) _then) = __$VpnProviderRefreshCopyWithImpl;
@override @useResult
$Res call({
 String section, String name, int interval, DateTime? lastUpdate
});




}
/// @nodoc
class __$VpnProviderRefreshCopyWithImpl<$Res>
    implements _$VpnProviderRefreshCopyWith<$Res> {
  __$VpnProviderRefreshCopyWithImpl(this._self, this._then);

  final _VpnProviderRefresh _self;
  final $Res Function(_VpnProviderRefresh) _then;

/// Create a copy of VpnProviderRefresh
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? section = null,Object? name = null,Object? interval = null,Object? lastUpdate = freezed,}) {
  return _then(_VpnProviderRefresh(
section: null == section ? _self.section : section // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,interval: null == interval ? _self.interval : interval // ignore: cast_nullable_to_non_nullable
as int,lastUpdate: freezed == lastUpdate ? _self.lastUpdate : lastUpdate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}


/// @nodoc
mixin _$VpnManagedGroups {

 String get selector; String get auto; String get fallback;
/// Create a copy of VpnManagedGroups
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnManagedGroupsCopyWith<VpnManagedGroups> get copyWith => _$VpnManagedGroupsCopyWithImpl<VpnManagedGroups>(this as VpnManagedGroups, _$identity);

  /// Serializes this VpnManagedGroups to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as VpnManagedGroups;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnManagedGroups&&(identical(other.selector, _this.selector) || other.selector == _this.selector)&&(identical(other.auto, _this.auto) || other.auto == _this.auto)&&(identical(other.fallback, _this.fallback) || other.fallback == _this.fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as VpnManagedGroups;
  return Object.hash(runtimeType,_this.selector,_this.auto,_this.fallback);
}

@override
String toString() {
  final _this = this as VpnManagedGroups;
  return 'VpnManagedGroups(selector: ${_this.selector}, auto: ${_this.auto}, fallback: ${_this.fallback})';
}


}

/// @nodoc
abstract mixin class $VpnManagedGroupsCopyWith<$Res>  {
  factory $VpnManagedGroupsCopyWith(VpnManagedGroups value, $Res Function(VpnManagedGroups) _then) = _$VpnManagedGroupsCopyWithImpl;
@useResult
$Res call({
 String selector, String auto, String fallback
});




}
/// @nodoc
class _$VpnManagedGroupsCopyWithImpl<$Res>
    implements $VpnManagedGroupsCopyWith<$Res> {
  _$VpnManagedGroupsCopyWithImpl(this._self, this._then);

  final VpnManagedGroups _self;
  final $Res Function(VpnManagedGroups) _then;

/// Create a copy of VpnManagedGroups
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? selector = null,Object? auto = null,Object? fallback = null,}) {
  return _then(VpnManagedGroups(
selector: null == selector ? _self.selector : selector // ignore: cast_nullable_to_non_nullable
as String,auto: null == auto ? _self.auto : auto // ignore: cast_nullable_to_non_nullable
as String,fallback: null == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VpnManagedGroups].
extension VpnManagedGroupsPatterns on VpnManagedGroups {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnManagedGroups value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnManagedGroups() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnManagedGroups value)  $default,){
final _that = this;
switch (_that) {
case _VpnManagedGroups():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnManagedGroups value)?  $default,){
final _that = this;
switch (_that) {
case _VpnManagedGroups() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String selector,  String auto,  String fallback)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnManagedGroups() when $default != null:
return $default(_that.selector,_that.auto,_that.fallback);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String selector,  String auto,  String fallback)  $default,) {final _that = this;
switch (_that) {
case _VpnManagedGroups():
return $default(_that.selector,_that.auto,_that.fallback);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String selector,  String auto,  String fallback)?  $default,) {final _that = this;
switch (_that) {
case _VpnManagedGroups() when $default != null:
return $default(_that.selector,_that.auto,_that.fallback);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnManagedGroups implements VpnManagedGroups {
  const _VpnManagedGroups({required this.selector, required this.auto, required this.fallback});
  factory _VpnManagedGroups.fromJson(Map<String, dynamic> json) => _$VpnManagedGroupsFromJson(json);

@override final  String selector;
@override final  String auto;
@override final  String fallback;

/// Create a copy of VpnManagedGroups
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnManagedGroupsCopyWith<_VpnManagedGroups> get copyWith => __$VpnManagedGroupsCopyWithImpl<_VpnManagedGroups>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnManagedGroupsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnManagedGroups&&(identical(other.selector, selector) || other.selector == selector)&&(identical(other.auto, auto) || other.auto == auto)&&(identical(other.fallback, fallback) || other.fallback == fallback));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,selector,auto,fallback);
}

@override
String toString() {
    return 'VpnManagedGroups(selector: $selector, auto: $auto, fallback: $fallback)';
}


}

/// @nodoc
abstract mixin class _$VpnManagedGroupsCopyWith<$Res> implements $VpnManagedGroupsCopyWith<$Res> {
  factory _$VpnManagedGroupsCopyWith(_VpnManagedGroups value, $Res Function(_VpnManagedGroups) _then) = __$VpnManagedGroupsCopyWithImpl;
@override @useResult
$Res call({
 String selector, String auto, String fallback
});




}
/// @nodoc
class __$VpnManagedGroupsCopyWithImpl<$Res>
    implements _$VpnManagedGroupsCopyWith<$Res> {
  __$VpnManagedGroupsCopyWithImpl(this._self, this._then);

  final _VpnManagedGroups _self;
  final $Res Function(_VpnManagedGroups) _then;

/// Create a copy of VpnManagedGroups
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? selector = null,Object? auto = null,Object? fallback = null,}) {
  return _then(_VpnManagedGroups(
selector: null == selector ? _self.selector : selector // ignore: cast_nullable_to_non_nullable
as String,auto: null == auto ? _self.auto : auto // ignore: cast_nullable_to_non_nullable
as String,fallback: null == fallback ? _self.fallback : fallback // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
