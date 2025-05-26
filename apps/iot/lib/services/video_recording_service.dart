import 'package:flutter/services.dart';
import 'dart:io';

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

/// 지속적인 비디오 녹화 및 이벤트 클립 추출을 위한 서비스
class VideoRecordingService {
  static const MethodChannel _channel = MethodChannel('com.example.iot/video_recording');
  
  /// 기본 설정
  static VideoRecorderConfig defaultConfig = VideoRecorderConfig(
    segmentSeconds: 10,
    gopSeconds: 1,
    fsyncIntervalMs: 2000,
    width: 1920,
    height: 1080,
    bitrate: 8000000,
    fps: 30,
  );
  
  /// 레코더 설정
  /// 
  /// 비디오 레코더의 다양한 설정을 구성합니다.
  Future<bool> configure(VideoRecorderConfig config) async {
    try {
      return await _channel.invokeMethod('configure', config.toMap()) ?? false;
    } catch (e) {
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
    try {
      return await _channel.invokeMethod('startRecording', config?.toMap()) ?? false;
    } catch (e) {
      print('비디오 녹화 시작 오류: $e');
      return false;
    }
  }
  
  /// 비디오 녹화 중지
  Future<bool> stopRecording() async {
    try {
      return await _channel.invokeMethod('stopRecording') ?? false;
    } catch (e) {
      print('비디오 녹화 중지 오류: $e');
      return false;
    }
  }
  
  /// 이벤트 클립 생성
  /// 
  /// 현재 시점을 기준으로 전후 세그먼트를 통합하여 이벤트 클립을 생성합니다.
  /// 반환값은 생성된 클립의 파일 경로입니다.
  Future<String?> createEventClip(int eventTimeMs) async {
    try {
      final String? uri = await _channel.invokeMethod<String>(
        'createEventClip',
        { 'eventTimeMs': eventTimeMs },
      );
      return uri;
    } catch (e) {
      print('이벤트 클립 생성 오류: $e');
      return null;
    }
  }
  
  /// 현재 녹화 중인지 확인
  Future<bool> isRecording() async {
    try {
      return await _channel.invokeMethod('isRecording') ?? false;
    } catch (e) {
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
    try {
      final result = await _channel.invokeMethod('getStorageStatus');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('저장 공간 상태 조회 오류: $e');
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
    try {
      final clipFile = File(clipPath);
      if (!await clipFile.exists()) {
        print('이벤트 클립 파일이 존재하지 않습니다: $clipPath');
        return null;
      }
      
      final destDirectory = Directory(destDir);
      if (!await destDirectory.exists()) {
        await destDirectory.create(recursive: true);
      }
      
      final fileName = newName ?? clipFile.path.split('/').last;
      final destPath = '$destDir/$fileName';
      
      await clipFile.copy(destPath);
      return destPath;
    } catch (e) {
      print('이벤트 클립 복사 오류: $e');
      return null;
    }
  }
}
