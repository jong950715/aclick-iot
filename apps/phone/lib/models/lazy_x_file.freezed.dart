// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lazy_x_file.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
LazyXFile _$LazyXFileFromJson(
  Map<String, dynamic> json
) {
        switch (json['runtimeType']) {
                  case 'local':
          return LocalLazyXFile.fromJson(
            json
          );
                case 'remote':
          return RemoteLazyXFile.fromJson(
            json
          );
                case 'dashCam':
          return DashCamLazyXFile.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'runtimeType',
  'LazyXFile',
  'Invalid union type "${json['runtimeType']}"!'
);
        }
      
}

/// @nodoc
mixin _$LazyXFile {

// TODO appServerFile 로 이름 변경
 LazyXFileMeta get meta;
/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LazyXFileCopyWith<LazyXFile> get copyWith => _$LazyXFileCopyWithImpl<LazyXFile>(this as LazyXFile, _$identity);

  /// Serializes this LazyXFile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LazyXFile&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,meta);

@override
String toString() {
  return 'LazyXFile(meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LazyXFileCopyWith<$Res>  {
  factory $LazyXFileCopyWith(LazyXFile value, $Res Function(LazyXFile) _then) = _$LazyXFileCopyWithImpl;
@useResult
$Res call({
 LazyXFileMeta meta
});


$LazyXFileMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$LazyXFileCopyWithImpl<$Res>
    implements $LazyXFileCopyWith<$Res> {
  _$LazyXFileCopyWithImpl(this._self, this._then);

  final LazyXFile _self;
  final $Res Function(LazyXFile) _then;

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? meta = null,}) {
  return _then(_self.copyWith(
meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as LazyXFileMeta,
  ));
}
/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LazyXFileMetaCopyWith<$Res> get meta {
  
  return $LazyXFileMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc

@JsonSerializable(explicitToJson: true)
class LocalLazyXFile extends LazyXFile {
   LocalLazyXFile({@XFileConverter() required this.xFile, required this.meta, final  String? $type}): $type = $type ?? 'local',super._();
  factory LocalLazyXFile.fromJson(Map<String, dynamic> json) => _$LocalLazyXFileFromJson(json);

@XFileConverter() final  XFile xFile;
@override final  LazyXFileMeta meta;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LocalLazyXFileCopyWith<LocalLazyXFile> get copyWith => _$LocalLazyXFileCopyWithImpl<LocalLazyXFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LocalLazyXFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LocalLazyXFile&&(identical(other.xFile, xFile) || other.xFile == xFile)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,xFile,meta);

@override
String toString() {
  return 'LazyXFile.local(xFile: $xFile, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $LocalLazyXFileCopyWith<$Res> implements $LazyXFileCopyWith<$Res> {
  factory $LocalLazyXFileCopyWith(LocalLazyXFile value, $Res Function(LocalLazyXFile) _then) = _$LocalLazyXFileCopyWithImpl;
@override @useResult
$Res call({
@XFileConverter() XFile xFile, LazyXFileMeta meta
});


@override $LazyXFileMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$LocalLazyXFileCopyWithImpl<$Res>
    implements $LocalLazyXFileCopyWith<$Res> {
  _$LocalLazyXFileCopyWithImpl(this._self, this._then);

  final LocalLazyXFile _self;
  final $Res Function(LocalLazyXFile) _then;

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? xFile = null,Object? meta = null,}) {
  return _then(LocalLazyXFile(
xFile: null == xFile ? _self.xFile : xFile // ignore: cast_nullable_to_non_nullable
as XFile,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as LazyXFileMeta,
  ));
}

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LazyXFileMetaCopyWith<$Res> get meta {
  
  return $LazyXFileMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class RemoteLazyXFile extends LazyXFile {
  const RemoteLazyXFile({required this.serverFilePath, required this.meta, final  String? $type}): $type = $type ?? 'remote',super._();
  factory RemoteLazyXFile.fromJson(Map<String, dynamic> json) => _$RemoteLazyXFileFromJson(json);

 final  String serverFilePath;
// TODO appServerFile 로 이름 변경
@override final  LazyXFileMeta meta;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoteLazyXFileCopyWith<RemoteLazyXFile> get copyWith => _$RemoteLazyXFileCopyWithImpl<RemoteLazyXFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RemoteLazyXFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoteLazyXFile&&(identical(other.serverFilePath, serverFilePath) || other.serverFilePath == serverFilePath)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,serverFilePath,meta);

@override
String toString() {
  return 'LazyXFile.remote(serverFilePath: $serverFilePath, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $RemoteLazyXFileCopyWith<$Res> implements $LazyXFileCopyWith<$Res> {
  factory $RemoteLazyXFileCopyWith(RemoteLazyXFile value, $Res Function(RemoteLazyXFile) _then) = _$RemoteLazyXFileCopyWithImpl;
@override @useResult
$Res call({
 String serverFilePath, LazyXFileMeta meta
});


@override $LazyXFileMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$RemoteLazyXFileCopyWithImpl<$Res>
    implements $RemoteLazyXFileCopyWith<$Res> {
  _$RemoteLazyXFileCopyWithImpl(this._self, this._then);

  final RemoteLazyXFile _self;
  final $Res Function(RemoteLazyXFile) _then;

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? serverFilePath = null,Object? meta = null,}) {
  return _then(RemoteLazyXFile(
serverFilePath: null == serverFilePath ? _self.serverFilePath : serverFilePath // ignore: cast_nullable_to_non_nullable
as String,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as LazyXFileMeta,
  ));
}

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LazyXFileMetaCopyWith<$Res> get meta {
  
  return $LazyXFileMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}

/// @nodoc

@JsonSerializable(explicitToJson: true)
class DashCamLazyXFile extends LazyXFile {
   DashCamLazyXFile({required this.eventRecord, required this.meta, final  String? $type}): $type = $type ?? 'dashCam',super._();
  factory DashCamLazyXFile.fromJson(Map<String, dynamic> json) => _$DashCamLazyXFileFromJson(json);

 final  EventRecord eventRecord;
@override final  LazyXFileMeta meta;

@JsonKey(name: 'runtimeType')
final String $type;


/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashCamLazyXFileCopyWith<DashCamLazyXFile> get copyWith => _$DashCamLazyXFileCopyWithImpl<DashCamLazyXFile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashCamLazyXFileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashCamLazyXFile&&(identical(other.eventRecord, eventRecord) || other.eventRecord == eventRecord)&&(identical(other.meta, meta) || other.meta == meta));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,eventRecord,meta);

@override
String toString() {
  return 'LazyXFile.dashCam(eventRecord: $eventRecord, meta: $meta)';
}


}

/// @nodoc
abstract mixin class $DashCamLazyXFileCopyWith<$Res> implements $LazyXFileCopyWith<$Res> {
  factory $DashCamLazyXFileCopyWith(DashCamLazyXFile value, $Res Function(DashCamLazyXFile) _then) = _$DashCamLazyXFileCopyWithImpl;
@override @useResult
$Res call({
 EventRecord eventRecord, LazyXFileMeta meta
});


@override $LazyXFileMetaCopyWith<$Res> get meta;

}
/// @nodoc
class _$DashCamLazyXFileCopyWithImpl<$Res>
    implements $DashCamLazyXFileCopyWith<$Res> {
  _$DashCamLazyXFileCopyWithImpl(this._self, this._then);

  final DashCamLazyXFile _self;
  final $Res Function(DashCamLazyXFile) _then;

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventRecord = null,Object? meta = null,}) {
  return _then(DashCamLazyXFile(
eventRecord: null == eventRecord ? _self.eventRecord : eventRecord // ignore: cast_nullable_to_non_nullable
as EventRecord,meta: null == meta ? _self.meta : meta // ignore: cast_nullable_to_non_nullable
as LazyXFileMeta,
  ));
}

/// Create a copy of LazyXFile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LazyXFileMetaCopyWith<$Res> get meta {
  
  return $LazyXFileMetaCopyWith<$Res>(_self.meta, (value) {
    return _then(_self.copyWith(meta: value));
  });
}
}


/// @nodoc
mixin _$LazyXFileMeta {

 String get name;// 원본 파일의 원래 이름
@UtcDateTimeConverter() UtcDateTime get createdAt; String? get safetyServerFilename; String? get xxh3Digest;
/// Create a copy of LazyXFileMeta
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LazyXFileMetaCopyWith<LazyXFileMeta> get copyWith => _$LazyXFileMetaCopyWithImpl<LazyXFileMeta>(this as LazyXFileMeta, _$identity);

  /// Serializes this LazyXFileMeta to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LazyXFileMeta&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.safetyServerFilename, safetyServerFilename) || other.safetyServerFilename == safetyServerFilename)&&(identical(other.xxh3Digest, xxh3Digest) || other.xxh3Digest == xxh3Digest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,createdAt,safetyServerFilename,xxh3Digest);

@override
String toString() {
  return 'LazyXFileMeta(name: $name, createdAt: $createdAt, safetyServerFilename: $safetyServerFilename, xxh3Digest: $xxh3Digest)';
}


}

/// @nodoc
abstract mixin class $LazyXFileMetaCopyWith<$Res>  {
  factory $LazyXFileMetaCopyWith(LazyXFileMeta value, $Res Function(LazyXFileMeta) _then) = _$LazyXFileMetaCopyWithImpl;
@useResult
$Res call({
 String name,@UtcDateTimeConverter() UtcDateTime createdAt, String? safetyServerFilename, String? xxh3Digest
});




}
/// @nodoc
class _$LazyXFileMetaCopyWithImpl<$Res>
    implements $LazyXFileMetaCopyWith<$Res> {
  _$LazyXFileMetaCopyWithImpl(this._self, this._then);

  final LazyXFileMeta _self;
  final $Res Function(LazyXFileMeta) _then;

/// Create a copy of LazyXFileMeta
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? createdAt = null,Object? safetyServerFilename = freezed,Object? xxh3Digest = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as UtcDateTime,safetyServerFilename: freezed == safetyServerFilename ? _self.safetyServerFilename : safetyServerFilename // ignore: cast_nullable_to_non_nullable
as String?,xxh3Digest: freezed == xxh3Digest ? _self.xxh3Digest : xxh3Digest // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// @nodoc
@JsonSerializable()

class _LazyXFileMeta implements LazyXFileMeta {
  const _LazyXFileMeta({required this.name, @UtcDateTimeConverter() required this.createdAt, this.safetyServerFilename, this.xxh3Digest});
  factory _LazyXFileMeta.fromJson(Map<String, dynamic> json) => _$LazyXFileMetaFromJson(json);

@override final  String name;
// 원본 파일의 원래 이름
@override@UtcDateTimeConverter() final  UtcDateTime createdAt;
@override final  String? safetyServerFilename;
@override final  String? xxh3Digest;

/// Create a copy of LazyXFileMeta
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LazyXFileMetaCopyWith<_LazyXFileMeta> get copyWith => __$LazyXFileMetaCopyWithImpl<_LazyXFileMeta>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LazyXFileMetaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LazyXFileMeta&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.safetyServerFilename, safetyServerFilename) || other.safetyServerFilename == safetyServerFilename)&&(identical(other.xxh3Digest, xxh3Digest) || other.xxh3Digest == xxh3Digest));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,createdAt,safetyServerFilename,xxh3Digest);

@override
String toString() {
  return 'LazyXFileMeta(name: $name, createdAt: $createdAt, safetyServerFilename: $safetyServerFilename, xxh3Digest: $xxh3Digest)';
}


}

/// @nodoc
abstract mixin class _$LazyXFileMetaCopyWith<$Res> implements $LazyXFileMetaCopyWith<$Res> {
  factory _$LazyXFileMetaCopyWith(_LazyXFileMeta value, $Res Function(_LazyXFileMeta) _then) = __$LazyXFileMetaCopyWithImpl;
@override @useResult
$Res call({
 String name,@UtcDateTimeConverter() UtcDateTime createdAt, String? safetyServerFilename, String? xxh3Digest
});




}
/// @nodoc
class __$LazyXFileMetaCopyWithImpl<$Res>
    implements _$LazyXFileMetaCopyWith<$Res> {
  __$LazyXFileMetaCopyWithImpl(this._self, this._then);

  final _LazyXFileMeta _self;
  final $Res Function(_LazyXFileMeta) _then;

/// Create a copy of LazyXFileMeta
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? createdAt = null,Object? safetyServerFilename = freezed,Object? xxh3Digest = freezed,}) {
  return _then(_LazyXFileMeta(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as UtcDateTime,safetyServerFilename: freezed == safetyServerFilename ? _self.safetyServerFilename : safetyServerFilename // ignore: cast_nullable_to_non_nullable
as String?,xxh3Digest: freezed == xxh3Digest ? _self.xxh3Digest : xxh3Digest // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
