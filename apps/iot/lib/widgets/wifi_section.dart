import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/services/console_manager.dart';
import 'package:iot/services/ephemeral_network_helper.dart';

import '../services/wifi_manager.dart';
mixin WifiSection<T extends ConsumerStatefulWidget> on ConsumerState<T> {

  Widget buildWifiSection() {
    final wifiCredentials = ref.watch(hotspotInfoProvider);
    final wifiConnectionStatus = ref.watch(wifiConnectionStatusProvider);

    if (wifiCredentials == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 16.0),
        child: Text('Wi-Fi 인증 정보가 아직 수신되지 않았습니다.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          const Text('Wi-Fi 연결 정보',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SSID: ${wifiCredentials.ssid}'),
                    const SizedBox(height: 4),
                    Text(
                      '연결 상태: $wifiConnectionStatus',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(wifiConnectionStatus),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _connectToWifi,
                icon: const Icon(Icons.wifi),
                label: const Text('Wi-Fi 연결'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0)),
                ),
              ),
            ],
          ),

          // HTTP 서버 섹션
          if (wifiConnectionStatus == '연결됨') ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('HTTP 서버 상태',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            // Ping 테스트 섹션
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Ping 테스트',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            // Ping 버튼 및 결과 표시
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Phone 앱 서버로 ping 요청 보내기',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 4),
                      Text('서버 URL: ${wifiCredentials.serverPath}'),
                    ],
                  ),
                ),
                Consumer(builder: (context, ref, _) {
                  final isPinging = ref.watch(isPingingProvider);

                  return ElevatedButton.icon(
                    onPressed: isPinging
                        ? null
                        : ref.read(wifiManagerProvider).sendPingRequest,
                    icon: isPinging
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.travel_explore),
                    label: Text(isPinging ? '요청 중...' : 'Ping 요청'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0)),
                    ),
                  );
                }),
              ],
            ),

            // Ping 응답 결과 표시
            Consumer(builder: (context, ref, _) {
              final pingResponse = ref.watch(pingResponseProvider);

              if (pingResponse == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.indigo.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ping 응답 결과:',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    if (pingResponse.containsKey('status'))
                      Text('상태: ${pingResponse['status']}'),
                    if (pingResponse.containsKey('message'))
                      Text('메시지: ${pingResponse['message']}'),
                    if (pingResponse.containsKey('count'))
                      Text('카운트: ${pingResponse['count']}'),
                    if (pingResponse.containsKey('timestamp'))
                      Text('타임스태프: ${pingResponse['timestamp']}'),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '연결됨':
        return Colors.green;
      case '연결 중...':
        return Colors.orange;
      case '연결 실패':
      case '연결 오류':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// WiFi 연결 시도 - HotspotInfo 모델 활용
  Future<void> _connectToWifi() async {
    // 저장된 인증 정보 가져오기
    final hotspotInfo = ref.read(hotspotInfoProvider);
    if (hotspotInfo == null) {
      _addMessage('저장된 Wi-Fi 인증 정보가 없습니다.');
      return;
    }

    try {
      _addMessage('Wi-Fi 연결 시도 중:\n'
          '- SSID: ${hotspotInfo.ssid}\n'
          '- IP 주소: ${hotspotInfo.ipAddress}\n'
          '- 포트: ${hotspotInfo.port}\n'
          '- 서버 URL: ${hotspotInfo.serverPath}');

      ref.read(wifiConnectionStatusProvider.notifier).state = '연결 중...';

      // 연결 시도
      final success = await EphemeralNetworkHelper.connectToSsid(
        ssid: hotspotInfo.ssid,
        password: hotspotInfo.password,
      );

      if (success) {
        _addMessage('Wi-Fi 연결 요청 성공. 연결 중... ${hotspotInfo.ssid}');
        ref.read(wifiConnectionStatusProvider.notifier).state = '연결됨';
      } else {
        _addMessage('Wi-Fi 연결 요청 실패: ${hotspotInfo.ssid}');
        ref.read(wifiConnectionStatusProvider.notifier).state = '연결 실패';
      }
    } catch (e) {
      _addMessage('Wi-Fi 연결 오류: $e');
      ref.read(wifiConnectionStatusProvider.notifier).state = '연결 오류';
    }
  }

  void _addMessage(String message) {
    ref.read(consoleProvider.notifier).addLog(message);
  }
}
