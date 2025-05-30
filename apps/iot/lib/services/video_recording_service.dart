import 'package:flutter/services.dart';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/repositories/app_logger.dart';


/// 비디오 레코더 설정을 위한 클래스
class VideoRecorderConfig {
  /// 저장 디렉토리 이름 (기본값: "video_segments")
  final String? outputDir;
  
  /// 세그먼트 길이 (초 단위, 기본값: 10)
  final int? segmentSeconds;
  
  /// GOP 길이 (초 단위, 기본값: 1)
  final int? gopSeconds;
  
  /// fsync 간격 (밀리초 단위, 기본값: 2000)
  final int? fsyncIntervalMs;
  
  /// 최대 저장 공간 크기 (MB 단위, 기본값: 32768 = 32GB)
  final int? maxStorageMB;
  
  /// 비디오 해상도 (기본값: 1920x1080)
  final int? width;
  final int? height;
  
  /// 비트레이트 (bps, 기본값: 8,000,000 = 8Mbps)
  final int? bitrate;
  
  /// 프레임레이트 (fps, 기본값: 30)
  final int? fps;
  
  /// 생성자
  VideoRecorderConfig({
    this.outputDir,
    this.segmentSeconds,
    this.gopSeconds,
    this.fsyncIntervalMs,
    this.maxStorageMB,
    this.width,
    this.height,
    this.bitrate,
    this.fps,
  });
  
  /// 맵으로 변환
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    
    if (outputDir != null) map['outputDir'] = outputDir;
    if (segmentSeconds != null) map['segmentSeconds'] = segmentSeconds;
    if (gopSeconds != null) map['gopSeconds'] = gopSeconds;
    if (fsyncIntervalMs != null) map['fsyncIntervalMs'] = fsyncIntervalMs;
    if (maxStorageMB != null) map['maxStorageMB'] = maxStorageMB;
    if (width != null) map['width'] = width;
    if (height != null) map['height'] = height;
    if (bitrate != null) map['bitrate'] = bitrate;
    if (fps != null) map['fps'] = fps;
    
    return map;
  }
}

final videoRecordingServiceProvider = Provider((ref) {
  final l = ref.read(appLoggerProvider.notifier);
  return VideoRecordingService(logger: l);
},);
/// 지속적인 비디오 녹화 및 이벤트 클립 추출을 위한 서비스
class VideoRecordingService {
  static const MethodChannel _channel = MethodChannel('com.example.iot/video_recording');

  final AppLogger logger;
  
  /// 기본 설정
  static VideoRecorderConfig defaultConfig = VideoRecorderConfig(
    segmentSeconds: 10,
    gopSeconds: 1,
    fsyncIntervalMs: 2000,
    width: 1920,
    height: 1080,
    bitrate: 10000000,
    fps: 30,
  );

  VideoRecordingService({required this.logger}) {
  }
  
  /// 레코더 설정
  /// 
  /// 비디오 레코더의 다양한 설정을 구성합니다.
  Future<bool> configure(VideoRecorderConfig config) async {
    logger.logInfo('비디오 레코더 설정 시도');
    logger.logDebug('설정 내용: ${config.toMap()}');
    try {
      final result = await _channel.invokeMethod('configure', config.toMap()) ?? false;
      logger.logInfo('비디오 레코더 설정 ${ result ? "성공" : "실패"}');
      return result;
    } catch (e) {
      logger.logError('비디오 레코더 설정 중 오류 발생: $e');
      print('비디오 레코더 설정 오류: $e');
      return false;
    }
  }
  
  /// 비디오 녹화 시작
  /// 
  /// 10초 단위 세그먼트로 지속적으로 녹화를 시작합니다.
  /// 각 세그먼트는 정확히 I-frame으로 시작하고 끝납니다.
  /// 
  /// [config]를 전달하면 녹화 시작 전에 설정을 적용합니다.
  Future<bool> startRecording({VideoRecorderConfig? config}) async {
    logger.logInfo('비디오 녹화 시작 요청');
    if (config != null) {
      logger.logInfo('사용자 정의 설정으로 녹화 시작');
      logger.logDebug('사용자 정의 설정: ${config.toMap()}');
    } else {
      logger.logInfo('기본 설정으로 녹화 시작');
    }
    
    try {
      final res = await _channel.invokeMethod('startRecording', config?.toMap()) ?? false;
      logger.logInfo(res? '비디오 녹화 시작 성공':'비디오 녹화 시작 실패');
      return res;
    } catch (e) {
      logger.logError('비디오 녹화 시작 중 오류 발생: $e');
      print('비디오 녹화 시작 오류: $e');
      return false;
    }
  }
  
  /// 비디오 녹화 중지
  Future<bool> stopRecording() async {
    logger.logInfo('비디오 녹화 중지 요청');
    try {
      final result = await _channel.invokeMethod('stopRecording') ?? false;
      logger.logInfo('비디오 녹화 중지 ${ result ? "성공" : "실패"}');
      return result;
    } catch (e) {
      logger.logError('비디오 녹화 중지 중 오류 발생: $e');
      print('비디오 녹화 중지 오류: $e');
      return false;
    }
  }
  
  /// 이벤트 클립 생성
  /// 
  /// 현재 시점을 기준으로 전후 세그먼트를 통합하여 이벤트 클립을 생성합니다.
  /// 반환값은 생성된 클립의 파일 경로입니다.
  Future<String?> createEventClip(int eventTimeMs) async {
    logger.logInfo('이벤트 클립 생성 요청: 이벤트 시간 $eventTimeMs');
    try {
      logger.logInfo('네이티브 채널을 통해 이벤트 클립 생성 요청 전송');
      final String? uri = await _channel.invokeMethod<String>(
        'createEventClip',
        { 'eventTimeMs': eventTimeMs },
      );
      
      if (uri != null) {
        logger.logInfo('이벤트 클립 생성 성공: $uri');
      } else {
        logger.logWarning('이벤트 클립 생성 실패: 반환된 URI 없음');
      }
      
      return uri;
    } catch (e) {
      logger.logError('이벤트 클립 생성 중 오류 발생: $e');
      print('이벤트 클립 생성 오류: $e');
      return null;
    }
  }
  
  /// 현재 녹화 중인지 확인
  Future<bool> isRecording() async {
    logger.logInfo('녹화 상태 확인 요청');
    try {
      final result = await _channel.invokeMethod('isRecording') ?? false;
      logger.logInfo('현재 녹화 상태: ${result ? "녹화 중" : "녹화 중지"}');
      return result;
    } catch (e) {
      logger.logError('녹화 상태 확인 중 오류 발생: $e');
      print('녹화 상태 확인 오류: $e');
      return false;
    }
  }
  
  /// 저장 공간 상태 조회
  /// 
  /// 반환 데이터:
  /// - totalSegmentSizeMB: 현재 세그먼트 총 크기 (MB)
  /// - availableSpaceMB: 사용 가능한 저장 공간 (MB)
  /// - segmentCount: 현재 세그먼트 파일 수
  /// - maxStorageSizeMB: 최대 허용 저장 크기 (MB)
  /// - outputDirectory: 출력 디렉토리 경로
  /// - segmentDurationSeconds: 세그먼트 길이 (초)
  /// - gopDurationSeconds: GOP 길이 (초)
  /// - fsyncIntervalMs: fsync 간격 (밀리초)
  /// - resolution: 해상도 (예: "1920x1080")
  /// - bitrate: 비트레이트 (bps)
  /// - fps: 프레임레이트
  Future<Map<String, dynamic>> getStorageStatus() async {
    logger.logInfo('저장 공간 상태 정보 요청');
    try {
      logger.logInfo('네이티브 채널을 통해 저장 공간 상태 정보 요청');
      final result = await _channel.invokeMethod('getStorageStatus');
      final resultMap = Map<String, dynamic>.from(result);
      
      logger.logInfo('저장 공간 상태 정보 받음');
      logger.logDebug('세그먼트 크기: ${resultMap['totalSegmentSizeMB']}MB, ' +
                    '가용 공간: ${resultMap['availableSpaceMB']}MB, ' +
                    '세그먼트 수: ${resultMap['segmentCount']}');
      
      return resultMap;
    } catch (e) {
      logger.logError('저장 공간 상태 조회 중 오류 발생: $e');
      print('저장 공간 상태 조회 오류: $e');
      
      logger.logWarning('기본 저장 공간 상태 정보 반환');
      return {
        'totalSegmentSizeMB': 0,
        'availableSpaceMB': 0,
        'segmentCount': 0,
        'maxStorageSizeMB': 32 * 1024
      };
    }
  }
  
  /// 이벤트 클립 파일을 특정 디렉토리로 복사
  /// 
  /// [clipPath]는 이벤트 클립 파일의 경로
  /// [destDir]은 복사할 대상 디렉토리
  /// [newName]은 새로운 파일 이름 (null이면 원본 파일 이름 사용)
  Future<String?> copyEventClipToDirectory(String clipPath, String destDir, {String? newName}) async {
    logger.logInfo('이벤트 클립 파일 복사 요청');
    logger.logInfo('원본 파일: $clipPath');
    logger.logInfo('대상 디렉토리: $destDir');
    if (newName != null) {
      logger.logInfo('새 파일명 지정됨: $newName');
    }
    
    try {
      final clipFile = File(clipPath);
      logger.logInfo('파일 존재 여부 확인');
      if (!await clipFile.exists()) {
        logger.logWarning('이벤트 클립 파일이 존재하지 않음: $clipPath');
        print('이벤트 클립 파일이 존재하지 않습니다: $clipPath');
        return null;
      }
      
      final destDirectory = Directory(destDir);
      logger.logInfo('대상 디렉토리 존재 여부 확인');
      if (!await destDirectory.exists()) {
        logger.logInfo('대상 디렉토리가 없어 생성 시작');
        await destDirectory.create(recursive: true);
        logger.logInfo('대상 디렉토리 생성 완료');
      }
      
      final fileName = newName ?? clipFile.path.split('/').last;
      final destPath = '$destDir/$fileName';
      logger.logInfo('복사할 대상 경로: $destPath');
      
      logger.logInfo('파일 복사 시작');
      await clipFile.copy(destPath);
      logger.logInfo('파일 복사 완료');
      return destPath;
    } catch (e) {
      logger.logError('이벤트 클립 복사 중 오류 발생: $e');
      print('이벤트 클립 복사 오류: $e');
      return null;
    }
  }
}
