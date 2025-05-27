import 'dart:convert';

import 'package:riverpod/riverpod.dart';
import 'package:iot/services/console_manager.dart';
import 'package:iot/services/ephemeral_network_helper.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';

/// WiFi 상태 표시를 위한 Provider
final wifiConnectionStatusProvider = StateProvider<String>((ref) => '연결 안됨');

/// WiFi 자격 증명 저장을 위한 Provider
final hotspotInfoProvider = StateProvider<HotspotInfo?>((ref) => null);

/// 핑 요청 중 상태 Provider
final isPingingProvider = StateProvider<bool>((ref) => false);

final pingResponseProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

typedef Reader<T> = T Function<T>(ProviderListenable<T> provider);

final wifiManagerProvider = Provider((ref) {
  return WifiManager(addLog: ref.read(consoleProvider.notifier).addLog, reader: ref.read);
});

class WifiManager {
  final Reader _read;
  late final Function(String msg) _addLog;

  WifiManager({required Function(String msg) addLog, required Reader reader})
      : _addLog = addLog,
        _read = reader;

  /// Phone 앱의 HTTP 서버로 Ping 요청 보내기
  Future<void> sendPingRequest() async {
    try {
      final hotspotInfo = _read(hotspotInfoProvider);
      if (hotspotInfo == null) {
        _addLog('Ping 요청 실패: Wi-Fi 연결 정보가 없습니다');
        return;
      }

      // URL 구성
      final pingUrl = '${hotspotInfo.serverPath}/ping';

      _addLog('Ping 요청 보내는 중: $pingUrl');
      _read(isPingingProvider.notifier).state = true;

      // GET 요청 보내기
      final response = await EphemeralNetworkHelper.requestOverWifi(
          method: "GET", url: pingUrl);
      // final response = await http
      //     .get(Uri.parse(pingUrl))
      //     .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        _addLog('Ping 성공! 응답: ${response.body}');

        // 응답 결과 저장
        _read(pingResponseProvider.notifier).state = jsonResponse;
      } else {
        _addLog('Ping 실패: 상태 코드 ${response.statusCode}');
        _read(pingResponseProvider.notifier).state = null;
      }
    } catch (e) {
      _addLog('Ping 요청 오류: $e');
      _read(pingResponseProvider.notifier).state = null;
    } finally {
      _read(isPingingProvider.notifier).state = false;
    }
  }
}
