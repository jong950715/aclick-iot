import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cross_file/cross_file.dart';
import 'dart:typed_data';
import 'package:xxh3/xxh3.dart';
import 'dart:typed_data';
import '../core/utc_date_time.dart';
import 'event_record.dart';

part 'lazy_x_file.freezed.dart';

part 'lazy_x_file.g.dart';

@freezed
sealed class LazyXFile with _$LazyXFile {
  const LazyXFile._();

  /// 사용자가 선택한 로컬 파일
  @JsonSerializable(explicitToJson: true)
  factory LazyXFile.local({
    @XFileConverter() required XFile xFile,
    required LazyXFileMeta meta,
  }) = LocalLazyXFile;

  /// Firestore 등에 저장된 signed URL 기반 파일
  @JsonSerializable(explicitToJson: true) // TODO 성능 오버헤드 있지만 무시할 수준?
  const factory LazyXFile.remote({
    required String serverFilePath, // TODO appServerFile 로 이름 변경
    required LazyXFileMeta meta,
  }) = RemoteLazyXFile;

  @JsonSerializable(explicitToJson: true)
  factory LazyXFile.dashCam({
    required EventRecord eventRecord,
    required LazyXFileMeta meta,
  }) = DashCamLazyXFile;

  String get name => switch (this) {
    LocalLazyXFile(xFile: final oldFile) => oldFile.name,
    RemoteLazyXFile(meta: final meta) => meta.name,
    DashCamLazyXFile(eventRecord: final eventRecord) => eventRecord.datetime.toString(),
  };

  factory LazyXFile.fromJson(Map<String, dynamic> json) =>
      _$LazyXFileFromJson(json);
}

extension LazyXFileLoader on LazyXFile {
  /// 기존 load(): 로컬/원격 파일 읽기를 지원
  Future<XFile> load() async {
    return switch (this) {
      LocalLazyXFile(xFile: final file) => file,
      RemoteLazyXFile(serverFilePath: final serverFilePath) => throw UnimplementedError(),
      DashCamLazyXFile() => throw UnimplementedError(),
    };
  }
}

@freezed
abstract class LazyXFileMeta with _$LazyXFileMeta {
  const factory LazyXFileMeta({
    required String name, // 원본 파일의 원래 이름
    @UtcDateTimeConverter() required UtcDateTime createdAt,
    String? safetyServerFilename,
    String? xxh3Digest,
  }) = _LazyXFileMeta;

  factory LazyXFileMeta.fromJson(Map<String, dynamic> json) =>
      _$LazyXFileMetaFromJson(json);
}

class XFileConverter implements JsonConverter<XFile, Map<String, dynamic>> {
  const XFileConverter();

  @override
  XFile fromJson(Map<String, dynamic> json) {
    return XFile(json['path']);
  }

  @override
  Map<String, dynamic> toJson(XFile xFile) {
    return {'path': xFile.toString()};
  }
}

class CustomTransferTask<T> {
  /// 진행된 바이트(sent)와 전체 바이트(total)를 레코드로 방출하는 스트림
  final Stream<(int sent, int total)> progress$;

  /// 완료 시점에 RemoteLazyXFile을 반환하는 Future
  final Future<T> result;

  /// 업로드 취소 함수
  final void Function() canceler;
  final String filename;

  CustomTransferTask({
    required this.filename,
    required this.progress$,
    required this.result,
    required this.canceler,
  });

  /// 이미 RemoteLazyXFile인 경우 즉시 완료되는 태스크를 만들어 줍니다.
  factory CustomTransferTask.completed(T file, {required name}) {
    // progress$ 에서 한 번에 완전(1:1) 진행 이벤트를 내보내고 스트림 종료
    final doneProgress = Stream<(int, int)>.value((1, 1));
    // resultFuture 는 즉시 성공으로 완료
    final doneResult = Future<T>.value(file);
    // canceler는 아무 일도 하지 않음
    void noop() {}

    return CustomTransferTask(
      filename: name,
      progress$: doneProgress,
      result: doneResult,
      canceler: noop,
    );
  }
}

extension XFileXxh3FileHasher on XFile {
  Future<String> xxh3({
    int chunkSize = 1024 * 1024,
    int maxChunkSize = 16 * 1024 * 1024 * 8,
  }) {
    return File(path).xxh3(chunkSize: chunkSize, maxChunkSize: maxChunkSize);
  }
}

extension FileXxh3FileHasher on File {
  Future<String> xxh3({
    int chunkSize = 1024 * 1024,
    int maxChunkSize = 16 * 1024 * 1024 * 8,
  }) async {
    final hasher = xxh3Stream();
    final raf = await open();

    // 1) 첫 청크 읽기
    Uint8List chunk = await raf.read(chunkSize);

    // 2) 청크가 남아 있는 한 계속 반복
    while (chunk.isNotEmpty) {
      if (chunkSize < maxChunkSize) {
        chunkSize = chunkSize * 2;
      }
      // 2-1) 다음 청크 읽기 시작 (비동기)
      final nextRead = raf.read(chunkSize);

      // 2-2) 현재 청크 해시
      hasher.update(chunk);

      // 2-3) 다음 청크를 기다리고, 변수 교체
      chunk = await nextRead;
    }

    await raf.close();
    return hasher.digestString();
  }
}
