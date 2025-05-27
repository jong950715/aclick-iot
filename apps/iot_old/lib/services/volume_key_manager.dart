import 'package:flutter/services.dart';

typedef VolumeUpCallback = void Function();

/// VolumeKeyManager를 초기화하여 Android 볼륨 업 키 이벤트를 Flutter로 전달받습니다.
///
/// 사용 예시:
/// ```dart
/// final volumeManager = VolumeKeyManager();
/// volumeManager.init(onVolumeUp: () {
///   // 볼륨 업 키 눌림 처리
/// });
/// // 앱 종료 또는 더 이상 필요 없을 때
/// volumeManager.dispose();
/// ```
class VolumeKeyManager {
  static const MethodChannel _channel = MethodChannel('custom/volume');

  VolumeUpCallback? upKeyCallback;

  VolumeKeyManager() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  void setOnVolumeUpCallback(VolumeUpCallback onVolumeUp) {
    upKeyCallback = onVolumeUp;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onVolumeUp') {
      upKeyCallback?.call();
    }
  }

  /// 리스너 해제 및 리소스 정리.
  void dispose() {
    _channel.setMethodCallHandler(null);
    upKeyCallback = null;
  }
}
