import 'package:iot/repositories/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';

part 'wifi_hotspot_service.g.dart';

@riverpod
class WifiHotspotService extends _$WifiHotspotService {
  final WifiHotspot _wifiHotspot = WifiHotspot();
  AppLogger get _logger => ref.watch(appLoggerProvider.notifier);
  bool _isHotspotStarted = false;

  @override
  HotspotInfo? build() {
    ref.keepAlive();
    return null;
  }

  Future<void> startHotspot() async {
    _logger.logInfo('WiFi 핫스팟 시작 요청');
    if (_isHotspotStarted) {
      _logger.logInfo('핫스팟이 이미 실행 중임, 중복 요청 무시');
      return;
    }
    // _isHotspotStarted = true;
    _logger.logInfo('핫스팟 생성 중...');
    state = await _wifiHotspot.startHotspot();
    
    if (state != null) {
      _logger.logInfo('핫스팟 시작 성공 - SSID: ${state?.ssid}, 비밀번호: ${state?.password}');
    } else {
      _logger.logWarning('핫스팟 시작되었으나 상태 정보가 없음');
    }
    _logger.logInfo("hotspot started");
  }

  Future<void> stopHotspot() async {
    _logger.logInfo('WiFi 핫스팟 중지 요청');
    if (!_isHotspotStarted) {
      _logger.logInfo('핫스팟이 실행 중이 아님, 중지 요청 무시');
      return;
    }
    _logger.logInfo('핫스팟 중지 시작');
    _isHotspotStarted = false;
    await _wifiHotspot.stopHotspot();
    _logger.logInfo('핫스팟 서비스 중지 완료');
    _logger.logInfo("hotspot stopped");
  }
}
