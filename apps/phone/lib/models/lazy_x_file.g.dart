// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lazy_x_file.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LocalLazyXFile _$LocalLazyXFileFromJson(Map<String, dynamic> json) =>
    LocalLazyXFile(
      xFile: const XFileConverter().fromJson(
        json['xFile'] as Map<String, dynamic>,
      ),
      meta: LazyXFileMeta.fromJson(json['meta'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$LocalLazyXFileToJson(LocalLazyXFile instance) =>
    <String, dynamic>{
      'xFile': const XFileConverter().toJson(instance.xFile),
      'meta': instance.meta.toJson(),
      'runtimeType': instance.$type,
    };

RemoteLazyXFile _$RemoteLazyXFileFromJson(Map<String, dynamic> json) =>
    RemoteLazyXFile(
      serverFilePath: json['serverFilePath'] as String,
      meta: LazyXFileMeta.fromJson(json['meta'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$RemoteLazyXFileToJson(RemoteLazyXFile instance) =>
    <String, dynamic>{
      'serverFilePath': instance.serverFilePath,
      'meta': instance.meta.toJson(),
      'runtimeType': instance.$type,
    };

DashCamLazyXFile _$DashCamLazyXFileFromJson(Map<String, dynamic> json) =>
    DashCamLazyXFile(
      eventRecord: EventRecord.fromJson(
        json['eventRecord'] as Map<String, dynamic>,
      ),
      meta: LazyXFileMeta.fromJson(json['meta'] as Map<String, dynamic>),
      $type: json['runtimeType'] as String?,
    );

Map<String, dynamic> _$DashCamLazyXFileToJson(DashCamLazyXFile instance) =>
    <String, dynamic>{
      'eventRecord': instance.eventRecord.toJson(),
      'meta': instance.meta.toJson(),
      'runtimeType': instance.$type,
    };

_LazyXFileMeta _$LazyXFileMetaFromJson(Map<String, dynamic> json) =>
    _LazyXFileMeta(
      name: json['name'] as String,
      createdAt: const UtcDateTimeConverter().fromJson(
        json['createdAt'] as String,
      ),
      safetyServerFilename: json['safetyServerFilename'] as String?,
      xxh3Digest: json['xxh3Digest'] as String?,
    );

Map<String, dynamic> _$LazyXFileMetaToJson(_LazyXFileMeta instance) =>
    <String, dynamic>{
      'name': instance.name,
      'createdAt': const UtcDateTimeConverter().toJson(instance.createdAt),
      'safetyServerFilename': instance.safetyServerFilename,
      'xxh3Digest': instance.xxh3Digest,
    };
