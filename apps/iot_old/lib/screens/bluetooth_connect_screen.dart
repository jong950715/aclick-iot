import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:iot/services/console_manager.dart';
import 'package:iot/services/wifi_manager.dart';
import 'package:iot/widgets/bluetooth_section.dart';
import 'package:iot/widgets/console_view.dart';
import 'package:iot/widgets/wifi_section.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

import '../services/ephemeral_network_helper.dart';

/// HTTP 서버 상태 Provider
final httpServerStatusProvider = StateProvider<bool>((ref) => false);

/// HTTP 서버 포트 Provider
final httpServerPortProvider = StateProvider<int?>((ref) => null);

/// 블루투스 연결 화면
class BluetoothConnectScreen extends ConsumerStatefulWidget {
  const BluetoothConnectScreen({super.key});

  @override
  ConsumerState<BluetoothConnectScreen> createState() =>
      _BluetoothConnectScreenState();
}

class _BluetoothConnectScreenState extends ConsumerState<BluetoothConnectScreen>
    with
        BluetoothConnectViewParts<BluetoothConnectScreen>,
        WifiSection<BluetoothConnectScreen> {
  final List<String> logs = [];
  final TextEditingController _messageController = TextEditingController();

  // final WifiHotspot _wifiHotspot = WifiHotspot();
  final EphemeralNetworkHelper _networkHelper = EphemeralNetworkHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _requestPermissions();
        initBluetooth(handleWifiCredentials: _handleWifiCredentials);
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final isConnected = ref.watch(bluetoothConnectionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('A-Click IoT 기기앱'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 상태 정보 카드
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('상태: ${isConnected ? '연결됨' : '연결 안됨'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (selectedDevice != null)
                    Text(
                        '연결된 디바이스: ${selectedDevice.name ?? '알 수 없음'} (${selectedDevice.address})',
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          // 작동 버튼들
          _buildButtons(),
          // 메시지 로그 영역 - 맨 아래에 배치
          Expanded(
            child: ConsoleView(
              messages: ref.watch(consoleProvider),
            ),
          ),
        ],
      ),
    );
  }

  /// WiFi 자격 증명 처리
  void _handleWifiCredentials(Map<String, dynamic> data) {
    // 수신한 데이터를 로그에 출력
    _addMessage('수신한 데이터: $data');

    // HotspotInfo 모델로 데이터 변환
    final hotspotInfo = HotspotInfo.fromJson(data);

    // Wi-Fi 인증 정보를 Provider에 저장
    ref.read(hotspotInfoProvider.notifier).state = hotspotInfo;

    _addMessage('WiFi 자격 증명 수신 및 저장됨:\n'
        '- SSID: ${hotspotInfo.ssid}\n'
        '- 비밀번호: ${hotspotInfo.password}\n'
        '- IP 주소: ${hotspotInfo.ipAddress}\n'
        '- 포트: ${hotspotInfo.port}\n'
        '- 서버 URL: ${hotspotInfo.serverPath}');
  }

  /// 메시지 추가
  void _addMessage(String message) {
    setState(() {
      logs.add(message);
    });
  }

  Widget _buildButtons() {
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return SizedBox(
      width: double.infinity,
      height: 150,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...buildBluetoothSection(),
            buildWifiSection(),
            // 파일 업로드 버튼 (Wi-Fi 연결 후에만 노출)
            Builder(
              builder: (context) {
                final hotspotInfo = ref.watch(hotspotInfoProvider);
                final wifiStatus = ref.watch(wifiConnectionStatusProvider);
                if (hotspotInfo == null || wifiStatus != '연결됨') {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('파일 선택 및 업로드'),
                    onPressed: () async {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles();
                      if (result == null || result.files.single.path == null) {
                        _addMessage('파일 선택이 취소되었습니다.');
                        return;
                      }
                      final filePath = result.files.single.path!;
                      final uploadUrl = '${hotspotInfo.serverPath}/upload';
                      _addMessage('파일 업로드 시작: $filePath → $uploadUrl');
                      try {
                        final response =
                            await EphemeralNetworkHelper.uploadFileOverWifi(
                          url: uploadUrl,
                          filePath: filePath,
                        );
                        if (response.statusCode == 201) {
                          _addMessage('업로드 성공! 서버 응답: ${response.body}');
                        } else {
                          _addMessage(
                              '업로드 실패: 상태 코드 ${response.statusCode}, 응답: ${response.body}');
                        }
                      } catch (e) {
                        _addMessage('파일 업로드 오류: $e');
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 어플리케이션 권한 요청
  Future<void> _requestPermissions() async {
    _addMessage('권한 요청 중...');

    // 필요한 권한 목록
    final permissions = [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
    ];

    // 권한 상태 확인
    Map<Permission, PermissionStatus> statuses = await permissions.request();

    // 권한 상태 로그
    statuses.forEach((permission, status) {
      _addMessage('${permission.toString()}: ${status.toString()}');
    });
  }

}
