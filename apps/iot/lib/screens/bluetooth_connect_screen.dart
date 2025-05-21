import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:fpdart/fpdart.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iot/services/http_server_service.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import '../services/network_helper.dart';

/// 블루투스 연결 상태를 저장하는 Provider
final bluetoothConnectionProvider = StateProvider<bool>((ref) => false);

/// 메시지 기록을 저장하는 Provider
final messagesProvider = StateProvider<List<String>>((ref) => []);

/// 선택된 디바이스를 저장하는 Provider
final selectedDeviceProvider = StateProvider<BluetoothDevice?>((ref) => null);

/// WiFi 상태 표시를 위한 Provider
final wifiConnectionStatusProvider = StateProvider<String>((ref) => '연결 안됨');

/// WiFi 자격 증명 저장을 위한 Provider
final hotspotInfoProvider = StateProvider<HotspotInfo?>((ref) => null);

/// HTTP 서버 서비스 Provider
final httpServerServiceProvider =
    Provider<HttpServerService>((ref) => HttpServerService());

/// HTTP 서버 상태 Provider
final httpServerStatusProvider = StateProvider<bool>((ref) => false);

/// HTTP 서버 포트 Provider
final httpServerPortProvider = StateProvider<int?>((ref) => null);

/// 핑 응답 결과 Provider
final pingResponseProvider =
    StateProvider<Map<String, dynamic>?>((ref) => null);

/// 핑 요청 중 상태 Provider
final isPingingProvider = StateProvider<bool>((ref) => false);

/// 블루투스 연결 화면
class BluetoothConnectScreen extends ConsumerStatefulWidget {
  const BluetoothConnectScreen({super.key});

  @override
  ConsumerState<BluetoothConnectScreen> createState() =>
      _BluetoothConnectScreenState();
}

class _BluetoothConnectScreenState
    extends ConsumerState<BluetoothConnectScreen> {
  final BluetoothService _bluetoothService = BluetoothService();
  late final BluetoothProtocolHandler _protocolHandler;
  final TextEditingController _messageController = TextEditingController();
  List<BluetoothDevice> _pairedDevices = [];
  bool _isScanning = false;
  StreamSubscription? _dataSubscription;
  // final WifiHotspot _wifiHotspot = WifiHotspot();
  final NetworkHelper _networkHelper = NetworkHelper();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _requestPermissions();
      },
    );
    _initBluetooth();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dataSubscription?.cancel();
    _bluetoothService.dispose();
    _stopHttpServer(); // HTTP 서버 중지
    super.dispose();
  }

  /// HTTP 서버 시작
  Future<void> _startHttpServer(int port) async {
    final httpService = ref.read(httpServerServiceProvider);

    _addMessage('HTTP 서버 시작 중... (포트: $port)');

    final success = await httpService.startServer(
      port: port,
      onLog: (message) {
        _addMessage('서버: $message');
      },
    );

    if (success) {
      ref.read(httpServerStatusProvider.notifier).state = true;
      ref.read(httpServerPortProvider.notifier).state = httpService.currentPort;
      _addMessage('HTTP 서버가 시작되었습니다 (포트: ${httpService.currentPort})');
    } else {
      _addMessage('HTTP 서버 시작 실패');
    }
  }

  /// HTTP 서버 중지
  Future<void> _stopHttpServer() async {
    final httpService = ref.read(httpServerServiceProvider);

    if (!httpService.isRunning) return;

    _addMessage('HTTP 서버 중지 중...');

    final success = await httpService.stopServer(
      onLog: (message) {
        _addMessage('서버: $message');
      },
    );

    if (success) {
      ref.read(httpServerStatusProvider.notifier).state = false;
      ref.read(httpServerPortProvider.notifier).state = null;
      _addMessage('HTTP 서버가 중지되었습니다');
    } else {
      _addMessage('HTTP 서버 중지 실패');
    }
  }

  /// Phone 앱의 HTTP 서버로 Ping 요청 보내기
  Future<void> _sendPingRequest() async {
    try {
      final hotspotInfo = ref.read(hotspotInfoProvider);
      if (hotspotInfo == null) {
        _addMessage('Ping 요청 실패: Wi-Fi 연결 정보가 없습니다');
        return;
      }

      // URL 구성
      final pingUrl = '${hotspotInfo.serverPath}/ping';

      _addMessage('Ping 요청 보내는 중: $pingUrl');
      ref.read(isPingingProvider.notifier).state = true;

      // GET 요청 보내기
      final response = await NetworkHelper.requestOverWifi(method: "GET", url: pingUrl);
      // final response = await http
      //     .get(Uri.parse(pingUrl))
      //     .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body) as Map<String, dynamic>;
        _addMessage('Ping 성공! 응답: ${response.body}');

        // 응답 결과 저장
        ref.read(pingResponseProvider.notifier).state = jsonResponse;
      } else {
        _addMessage('Ping 실패: 상태 코드 ${response.statusCode}');
        ref.read(pingResponseProvider.notifier).state = null;
      }
    } catch (e) {
      _addMessage('Ping 요청 오류: $e');
      ref.read(pingResponseProvider.notifier).state = null;
    } finally {
      ref.read(isPingingProvider.notifier).state = false;
    }
  }

  /// Bluetooth 초기화
  Future<void> _initBluetooth() async {
    try {
      // 권한 확인
      final hasBluetoothConnectPermission =
          await Permission.bluetoothConnect.isGranted;
      final hasBluetoothScanPermission =
          await Permission.bluetoothScan.isGranted;
      final hasLocationPermission =
          await Permission.locationWhenInUse.serviceStatus.isEnabled;

      if (!hasBluetoothConnectPermission ||
          !hasBluetoothScanPermission ||
          !hasLocationPermission) {
        _addMessage('블루투스 초기화 실패: 필요한 권한이 없습니다.');
        _addMessage('권한을 허용한 후 어플리케이션을 다시 시작해주세요.');
        return;
      }

      // 블루투스 초기화
      final result = await _bluetoothService.initializeAdapter();
      if (!result) {
        _addMessage('블루투스 사용 불가능');
        return;
      }

      // Custom UUID 설정 - Core 패키지의 상수 사용
      await _bluetoothService.setCustomUuid(BLUETOOTH_IOT_UUID);
      _addMessage('UUID 사용 중: $BLUETOOTH_IOT_UUID');

      // 블루투스 활성화 요청
      if (!(await _bluetoothService.isEnabled())) {
        _addMessage('블루투스 활성화 요청 중...');
        final enabled = await _bluetoothService.requestEnable();
        if (!enabled) {
          _addMessage('블루투스를 활성화해주세요');
          return;
        }
        _addMessage('블루투스 활성화 완료');
      }

      _protocolHandler = BluetoothProtocolHandler.fromConnectionStream(
          _bluetoothService.connectionStream);
      _addMessage('블루투스 초기화 완료');

      // Wi-Fi 권한 확인
      final hasNearbyWifiDevicesPermission =
          await Permission.nearbyWifiDevices.isGranted;
      if (hasNearbyWifiDevicesPermission) {
        _addMessage('Wi-Fi 권한 확인 완료');
      } else {
        _addMessage('Wi-Fi 연결을 위해 Wi-Fi 권한이 필요합니다.');
      }

      // 데이터 수신 리스너 설정
      _setupDataListener();

      // 페어링된 장치 로드
      await _loadPairedDevices();
    } catch (e) {
      _addMessage('Error initializing Bluetooth: $e');
    }
  }

  /// 데이터 수신 리스너 설정
  void _setupDataListener() {
    _dataSubscription = _protocolHandler.messageStream.listen(
      (Either<String, Map<String, dynamic>> message) => message.match(
        (l) => _addMessage('메시지 오류: $l'),
        (r) => _processReceivedMessage(r),
      ),
    );
  }

  /// 수신된 메시지 처리
  void _processReceivedMessage(Map<String, dynamic> message) {
    try {
      final commandType = message['commandType'];
      final data = message['data'];

      _addMessage(
          '메시지 수신: $commandType, ${data != null ? '데이터 있음' : '데이터 없음'}');

      if (commandType == CommandType.wifiCredentials && data != null) {
        _handleWifiCredentials(data);
      } else if (commandType == CommandType.handshake && data != null) {
        _addMessage('핸드셰이크 수신: ${data.toString()}');
        // 필요시 핸드셰이크 응답 처리
      } else {
        _addMessage('알 수 없는 메시지 유형: $commandType, 데이터: $data');
      }
    } catch (e) {
      _addMessage('메시지 처리 오류: $e');
    }
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
      final success = await NetworkHelper.connectToSsid(
        ssid: hotspotInfo.ssid,
        password: hotspotInfo.password,
      );

      if (success) {
        _addMessage('Wi-Fi 연결 요청 성공. 연결 중... ${hotspotInfo.ssid}');
        ref.read(wifiConnectionStatusProvider.notifier).state = '연결됨';

        // Wi-Fi 연결 성공 후 HTTP 서버 시작
        _startHttpServer(hotspotInfo.port ?? 8080);
      } else {
        _addMessage('Wi-Fi 연결 요청 실패: ${hotspotInfo.ssid}');
        ref.read(wifiConnectionStatusProvider.notifier).state = '연결 실패';
      }
    } catch (e) {
      _addMessage('Wi-Fi 연결 오류: $e');
      ref.read(wifiConnectionStatusProvider.notifier).state = '연결 오류';
    }
  }

  /// 페어링된 장치 로드
  Future<void> _loadPairedDevices() async {
    try {
      final devices = await _bluetoothService.getPairedDevices();
      setState(() {
        _pairedDevices = devices;
      });
      _addMessage('Loaded ${devices.length} paired devices');
    } catch (e) {
      _addMessage('Error loading paired devices: $e');
    }
  }

  /// 장치 스캔 시작
  Future<void> _startScan() async {
    try {
      setState(() {
        _isScanning = true;
      });
      await _bluetoothService.startScan();
      _addMessage('Scanning for devices...');

      // 10초 후 스캔 중지
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          _stopScan();
        }
      });
    } catch (e) {
      _addMessage('Error starting scan: $e');
      setState(() {
        _isScanning = false;
      });
    }
  }

  /// 장치 스캔 중지
  Future<void> _stopScan() async {
    try {
      await _bluetoothService.stopScan();
      setState(() {
        _isScanning = false;
      });
      _addMessage('Scan stopped');
    } catch (e) {
      _addMessage('Error stopping scan: $e');
    }
  }

  /// 선택한 장치에 연결
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _addMessage('Connecting to ${device.name ?? device.address}...');

      // 연결 시도
      final BluetoothConnection connection =
          await _bluetoothService.connect(device);

      ref.read(bluetoothConnectionProvider.notifier).state = true;
      ref.read(selectedDeviceProvider.notifier).state = device;

      _addMessage('Connected to ${device.name ?? device.address}');
    } catch (e) {
      _addMessage('Connection error: $e');
    }
  }

  /// 연결 해제
  Future<void> _disconnect() async {
    try {
      await _bluetoothService.disconnect();
      ref.read(bluetoothConnectionProvider.notifier).state = false;
      ref.read(selectedDeviceProvider.notifier).state = null;
      _addMessage('Disconnected');
    } catch (e) {
      _addMessage('Disconnect error: $e');
    }
  }

  /// 메시지 추가
  void _addMessage(String message) {
    ref.read(messagesProvider.notifier).state = [
      ...ref.read(messagesProvider),
      message,
    ];
  }

  Widget _buildButtons() {
    final isConnected = ref.watch(bluetoothConnectionProvider);
    final messages = ref.watch(messagesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return SizedBox(
      width: double.infinity,
      height: 150,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isConnected) ...[
              // 연결된 상태 UI
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '현재 연결',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDevice?.name ??
                                selectedDevice?.address ??
                                '알 수 없는 기기',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _disconnect,
                            icon: const Icon(Icons.bluetooth_disabled),
                            label: const Text('연결 해제'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              // minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.0)),
                            ),
                          ),
                        ],
                      ),

                      // Wi-Fi 연결 영역
                      _buildWifiConnectionSection(),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // 연결되지 않은 상태 UI
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                          backgroundColor: _isScanning ? Colors.amber : null,
                        ),
                        onPressed: _isScanning ? null : _startScan,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                                _isScanning
                                    ? Icons.bluetooth_searching
                                    : Icons.bluetooth_connected,
                                size: 24),
                            const SizedBox(height: 4),
                            Text(_isScanning ? '스캔 중...' : '1. 블루투스 기기 스캔'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0)),
                        ),
                        onPressed: _loadPairedDevices,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.refresh, size: 24),
                            const SizedBox(height: 4),
                            const Text('2. 페어링 새로고침'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Paired Devices:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _pairedDevices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bluetooth_disabled,
                                size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('페어링된 블루투스 기기가 없습니다',
                                style: TextStyle(
                                    color: Colors.grey.shade600, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('위에서 기기 스캔을 시도해보세요',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _pairedDevices.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final device = _pairedDevices[index];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            leading: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.bluetooth,
                                color: Colors.blue.shade700,
                                size: 24,
                              ),
                            ),
                            title: Text(
                              device.name ?? '알 수 없는 기기',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(device.address),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 8.0, horizontal: 12.0),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0)),
                                backgroundColor: Colors.blue.shade500,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => _connectToDevice(device),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.link, size: 16),
                                  SizedBox(width: 4),
                                  Text('연결'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Wi-Fi 연결 및 HTTP 서버 섹션 위젯 구현
  Widget _buildWifiConnectionSection() {
    final wifiCredentials = ref.watch(hotspotInfoProvider);
    final wifiConnectionStatus = ref.watch(wifiConnectionStatusProvider);
    final httpServerStatus = ref.watch(httpServerStatusProvider);
    final httpServerPort = ref.watch(httpServerPortProvider);

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
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '서버 상태: ${httpServerStatus ? "실행 중" : "중지됨"}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: httpServerStatus ? Colors.green : Colors.red,
                        ),
                      ),
                      if (httpServerStatus && httpServerPort != null) ...[
                        const SizedBox(height: 4),
                        Text('포트: $httpServerPort'),
                        const SizedBox(height: 4),
                        Text(
                            'API 주소: http://${wifiCredentials.ipAddress}:$httpServerPort/ping'),
                      ],
                    ],
                  ),
                ),
                if (httpServerStatus)
                  ElevatedButton.icon(
                    onPressed: _stopHttpServer,
                    icon: const Icon(Icons.stop),
                    label: const Text('서버 중지'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0)),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () =>
                        _startHttpServer(wifiCredentials.port ?? 8080),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('서버 시작'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0)),
                    ),
                  ),
              ],
            ),

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
                    onPressed: isPinging ? null : _sendPingRequest,
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

  /// Wi-Fi 상태에 따른 색상 반환
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

    // 위치 권한 확인 (Wi-Fi 연결에 필요)
    if (!statuses[Permission.locationAlways]!.isGranted) {
      _addMessage('위치 권한이 필요합니다. 권한을 허용해주세요.');
      _showPermissionDialog('위치 권한', 'Wi-Fi 연결 기능을 사용하기 위해 위치 권한이 필요합니다.');
    }

    // 블루투스 권한 확인
    if (!statuses[Permission.bluetoothConnect]!.isGranted) {
      _addMessage('블루투스 연결 권한이 필요합니다. 권한을 허용해주세요.');
      _showPermissionDialog('블루투스 권한', '기기 연결을 위해 블루투스 권한이 필요합니다.');
    }
  }

  /// 권한 설명 다이얼로그 표시
  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('설정으로 이동'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('취소'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(bluetoothConnectionProvider);
    final messages = ref.watch(messagesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

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
          _buildButtons(),

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
                    FilePickerResult? result = await FilePicker.platform.pickFiles();
                    if (result == null || result.files.single.path == null) {
                      _addMessage('파일 선택이 취소되었습니다.');
                      return;
                    }
                    final filePath = result.files.single.path!;
                    final uploadUrl = '${hotspotInfo.serverPath}/upload';
                    _addMessage('파일 업로드 시작: $filePath → $uploadUrl');
                    try {
                      final response = await NetworkHelper.uploadFileOverWifi(
                        url: uploadUrl,
                        filePath: filePath,
                      );
                      if (response.statusCode == 201) {
                        _addMessage('업로드 성공! 서버 응답: ${response.body}');
                      } else {
                        _addMessage('업로드 실패: 상태 코드 ${response.statusCode}, 응답: ${response.body}');
                      }
                    } catch (e) {
                      _addMessage('파일 업로드 오류: $e');
                    }
                  },
                ),
              );
            },
          ),

          // 메시지 로그 영역 - 맨 아래에 배치
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                elevation: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: Colors.blue.shade100,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: const Row(
                        children: [
                          Icon(Icons.terminal, size: 20),
                          SizedBox(width: 8),
                          Text('로그 콘솔',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(messages[index],
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 13)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
