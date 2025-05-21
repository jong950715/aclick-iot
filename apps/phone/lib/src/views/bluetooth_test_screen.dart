import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:fpdart/fpdart.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:phone/src/services/http_server_service.dart';

// 블루투스 프로토콜 핸들러 제공자
final bluetoothProtocolHandlerProvider =
    Provider<BluetoothProtocolHandler>((ref) {
  final service = ref.read(bluetoothServiceProvider);
  return BluetoothProtocolHandler.fromConnectionStream(
      service.connectionStream);
});

// 블루투스 서비스 제공자
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  return BluetoothService();
});

// 연결 상태 제공자
final connectionStateProvider = StateProvider<BluetoothConnectionState>((ref) {
  return BluetoothConnectionState.disconnected;
});

// 선택된 디바이스 제공자
final selectedDeviceProvider = StateProvider<BluetoothDevice?>((ref) => null);

// 발견된 디바이스 목록 제공자
final discoveredDevicesProvider =
    StateProvider<List<BluetoothDevice>>((ref) => []);

// 연결 로그 제공자
final logProvider = StateProvider<List<String>>((ref) => []);

// Wi-Fi 핫스팟 정보 제공자
final hotspotInfoProvider = StateProvider<HotspotInfo?>((ref) => null);

// HTTP 서버 서비스 제공자
final httpServerServiceProvider = Provider<HttpServerService>((ref) => HttpServerService());

// HTTP 서버 상태 제공자 (실행 중인지 여부)
final httpServerStatusProvider = StateProvider<bool>((ref) => false);

// HTTP 서버 포트 제공자
final httpServerPortProvider = StateProvider<int?>((ref) => null);

// HTTP 서버 핑 카운트 제공자
final httpServerPingCountProvider = StateProvider<int>((ref) => 0);

// HTTP 서버 포트 상수
const int HTTP_SERVER_PORT = 8080;

class BluetoothTestScreen extends ConsumerStatefulWidget {
  const BluetoothTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BluetoothTestScreen> createState() =>
      _BluetoothTestScreenState();
}

class _BluetoothTestScreenState extends ConsumerState<BluetoothTestScreen> {
  final List<StreamSubscription> _subscriptions = [];
  final TextEditingController _messageController = TextEditingController();
  
  // WifiHotspot 인스턴스
  final WifiHotspot _wifiHotspot = WifiHotspot();
  
  // HTTP 서버 인스턴스
  HttpServer? _httpServer;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _requestPermissions());
    _initBluetooth();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _messageController.dispose();
    _stopHotspot();
    _stopServer();
    super.dispose();
  }

  void _initBluetooth() async {
    final service = ref.read(bluetoothServiceProvider);
    final protocolHandler = ref.read(bluetoothProtocolHandlerProvider);

    try {
      // 블루투스 권한 확인
      final hasBluetoothPermission = await Permission.bluetoothConnect.isGranted;
      final hasBluetoothScanPermission = await Permission.bluetoothScan.isGranted;
      
      if (!hasBluetoothPermission || !hasBluetoothScanPermission) {
        _addLog('블루투스 초기화 실패: 필요한 권한이 없습니다.');
        return;
      }
      
      // 상태 변화 리스너 설정
      _subscriptions.add(service.connectionStateChanges.listen((state) {
        ref.read(connectionStateProvider.notifier).state = state;
        _addLog('연결 상태 변경: $state');
      }));

      // 디바이스 발견 리스너 설정
      _subscriptions.add(service.discoveredDevices.listen((device) {
        final devices = [...ref.read(discoveredDevicesProvider)];
        if (!devices.any((d) => d.address == device.address)) {
          devices.add(device);
          ref.read(discoveredDevicesProvider.notifier).state = devices;
          _addLog('디바이스 발견: ${device.name} (${device.address})');
        }
      }));

      // 연결 이벤트 리스너 설정
      _subscriptions.add(service.connectionEstablished.listen((device) {
        ref.read(selectedDeviceProvider.notifier).state = device;
        _addLog('${device.name}에 연결됨');
        protocolHandler.sendHandshake(deviceId: device.address, deviceName: device.name ?? "");
      }));

      // 데이터 수신 이벤트 리스너 설정
      _subscriptions.add(protocolHandler.messageStream
          .listen((Either<String, Map<String, dynamic>> message) {
        message.match(
          (l) => _addLog('에러 발생: $l'),
          (r) => _addLog('수신된 데이터: $r'),
        );
      }));

      // 어댑터 초기화
      final isEnabled = await service.initializeAdapter();
      _addLog('Bluetooth 어댑터 초기화: ${isEnabled ? '성공' : '실패'}');
    } catch (e) {
      _addLog('초기화 오류: $e');
    }
  }

  void _startListening() async {
    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      final listening =
          await bluetoothService.listenUsingRfcomm(uuid: BLUETOOTH_IOT_UUID);
      _addLog('블루투스 listening: $listening');

      // IoT 장치가 연결되면 핫스팟을 시작하고 파일 전송을 위한 HTTP 서버를 준비
      // 우선 debugging 을 위해 수동으로
      // _subscriptions.add(bluetoothService.connectionEstablished.listen((device) async {
      //   _addLog('${device.name}에 연결됨 - 핫스팟 시작 중...');
      //   await _startHotspot();
      //   await _sendWifiCredentials();
      //   await _startServer();
      // }));
    } catch (e) {
      _addLog('서버 시작 오류: $e');
    }
  }

  Future<void> _requestPermissions() async {
    _addLog('권한 요청 중...');
    
    // 필요한 권한 목록
    final permissions = [
      Permission.bluetooth,
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
      _addLog('${permission.toString()}: ${status.toString()}');
    });
    
    // 위치 권한 확인 (Wi-Fi 핫스팟에 필요)
    if (!statuses[Permission.locationAlways]!.isGranted) {
      _addLog('위치 권한이 필요합니다. 권한을 허용해주세요.');
      _showPermissionDialog('위치 권한', '핫스팟 기능을 사용하기 위해 위치 권한이 필요합니다.');
    }
    
    // 블루투스 권한 확인
    if (!statuses[Permission.bluetoothConnect]!.isGranted) {
      _addLog('블루투스 연결 권한이 필요합니다. 권한을 허용해주세요.');
      _showPermissionDialog('블루투스 권한', '기기 연결을 위해 블루투스 권한이 필요합니다.');
    }
  }
  
  void _showPermissionDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text('설정으로 이동'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _startHotspot() async {
    try {
      // 권한 확인
      final hasLocationPermission = await Permission.locationAlways.isGranted;
      final hasWifiDevicesPermission = await Permission.nearbyWifiDevices.isGranted;
      
      if (!hasLocationPermission || !hasWifiDevicesPermission) {
        _addLog('핫스팟 시작 실패: 필요한 권한이 없습니다.');
        await _requestPermissions();
        return;
      }
      
      _addLog('로컬 Wi-Fi 핫스팟 시작 중...');
      final hotspotInfo = await _wifiHotspot.startHotspot();

      _addLog('핫스팟 시작됨 - SSID: ${hotspotInfo.ssid}, PW: ${hotspotInfo.password}, IP: ${hotspotInfo.ipAddress}');

      // 핫스팟 정보 저장
      ref.read(hotspotInfoProvider.notifier).state = hotspotInfo;

      return;
    } catch (e) {
      _addLog('핫스팟 시작 오류: $e');
      rethrow;
    }
  }

  void _stopHotspot() async {
    try {
      final isActive = await _wifiHotspot.isHotspotActive();
      if (isActive) {
        await _wifiHotspot.stopHotspot();
        _addLog('핫스팟 중지됨');
      }
      ref.read(hotspotInfoProvider.notifier).state = null;
    } catch (e) {
      _addLog('핫스팟 중지 오류: $e');
    }
  }

  Future<void> _sendWifiCredentials() async {
    if (ref.read(connectionStateProvider) !=
        BluetoothConnectionState.connected) {
      _addLog('WiFi 인증 정보 전송 실패: 블루투스가 연결되지 않음');
      return;
    }

    final selectedDevice = ref.read(selectedDeviceProvider);
    if (selectedDevice == null) {
      _addLog('WiFi 인증 정보 전송 실패: 연결된 장치가 없음');
      return;
    }

    final hotspotInfo = ref.read(hotspotInfoProvider);
    if (hotspotInfo == null) {
      _addLog('WiFi 인증 정보 전송 실패: 핫스팟 정보가 없음');
      return;
    }

    try {
      final protocolHandler = ref.read(bluetoothProtocolHandlerProvider);

      // 직렬화된 데이터를 로그에 출력
      _addLog('보낼 데이터: ${hotspotInfo.toJson()}');

      // 메시지 전송
      await protocolHandler.sendWifiCredentials(
        hotspotInfoJson: hotspotInfo.toJson(),
      );
      _addLog('WiFi 인증 정보 전송됨: SSID=${hotspotInfo.ssid}, PWD=${hotspotInfo.password}, URL=${hotspotInfo.serverPath}');
    } catch (e) {
      _addLog('WiFi 인증 정보 전송 오류: $e');
    }
  }

  Future<void> _startServer() async {
    try {
      final hotspotInfo = ref.read(hotspotInfoProvider);
      if (hotspotInfo == null) {
        _addLog('HTTP 서버 시작 실패: 핫스팟 정보가 없음');
        return;
      }
      
      // HTTP 서버 서비스 가져오기
      final httpService = ref.read(httpServerServiceProvider);
      
      _addLog('HTTP 서버 시작 중... 포트: $HTTP_SERVER_PORT');
      
      // 서버 시작
      final success = await httpService.startServer(
        port: HTTP_SERVER_PORT,
        onLog: (message) {
          _addLog('서버: $message');
        },
      );
      
      if (success) {
        // 상태 업데이트
        ref.read(httpServerStatusProvider.notifier).state = true;
        ref.read(httpServerPortProvider.notifier).state = httpService.currentPort;
        
        _addLog('HTTP 서버가 ${hotspotInfo.ipAddress}:${httpService.currentPort} 에서 시작됨');
        _addLog('핑 테스트 URL: http://${hotspotInfo.ipAddress}:${httpService.currentPort}/ping');
      } else {
        _addLog('HTTP 서버 시작 실패');
      }
    } catch (e) {
      _addLog('HTTP 서버 시작 오류: $e');
    }
  }

  Future<void> _stopServer() async {
    try {
      // 기존 서버 인스턴스 종료
      if (_httpServer != null) {
        await _httpServer?.close();
        _httpServer = null;
      }
      
      // 새 HTTP 서버 서비스 사용
      final httpService = ref.read(httpServerServiceProvider);
      
      if (!httpService.isRunning) return;
      
      _addLog('HTTP 서버 중지 중...');
      
      final success = await httpService.stopServer(
        onLog: (message) {
          _addLog('서버: $message');
        },
      );
      
      if (success) {
        ref.read(httpServerStatusProvider.notifier).state = false;
        ref.read(httpServerPortProvider.notifier).state = null;
        ref.read(httpServerPingCountProvider.notifier).state = 0;
        _addLog('HTTP 서버가 중지되었습니다');
      } else {
        _addLog('HTTP 서버 중지 실패');
      }
    } catch (e) {
      _addLog('HTTP 서버 중지 오류: $e');
    }
  }

  void _addLog(String message) {
    final logs = [...ref.read(logProvider)];
    logs.add('${DateTime.now().toString().substring(11, 19)} $message');
    if (logs.length > 100) logs.removeAt(0);
    ref.read(logProvider.notifier).state = logs;
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionStateProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final HotspotInfo? hotspotInfo = ref.watch(hotspotInfoProvider);
    final logs = ref.watch(logProvider);

    final isConnected = connectionState == BluetoothConnectionState.connected ||
        connectionState == BluetoothConnectionState.transferring;



    final isHotspotOn = hotspotInfo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('A-Click IoT 모바일앱'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('상태: $connectionState',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (selectedDevice != null)
                      Text(
                          '연결된 디바이스: ${selectedDevice.name} (${selectedDevice.address})',
                          style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          ),

          // 메인 기능 버튼
          Container(
            margin: const EdgeInsets.only(top: 10.0, bottom: 5.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                    ),
                    onPressed: () => _startListening(), 
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bluetooth, size: 24),
                        const SizedBox(height: 4),
                        const Text('1. 블루투스 리스닝'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final hotspotInfo = ref.watch(hotspotInfoProvider);
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12.0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                          backgroundColor: hotspotInfo != null ? Colors.amber : null,
                        ),
                        onPressed: hotspotInfo == null ? _startHotspot : _stopHotspot,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(hotspotInfo == null ? Icons.wifi_tethering : Icons.wifi_tethering_off, size: 24),
                            const SizedBox(height: 4),
                            Text(hotspotInfo == null ? '2. 핫스팟 시작' : '핫스팟 중지'),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          Container(
            margin: const EdgeInsets.only(bottom: 10.0),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      backgroundColor: isConnected ? null : Colors.grey,
                    ),
                    onPressed: isConnected ? _sendWifiCredentials : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi, size: 24),
                        const SizedBox(height: 4),
                        const Text('3. SSID/PW 송신'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                      backgroundColor: isConnected ? null : Colors.grey,
                    ),
                    onPressed: isConnected ? _startServer : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns, size: 24),
                        const SizedBox(height: 4),
                        const Text('4. Server 열기'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Card(
                child: ListView.builder(
                  itemCount: logs.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 2.0),
                      child: Text(logs[logs.length - 1 - index],
                          style: const TextStyle(fontFamily: 'monospace')),
                    );
                  },
                ),
              ),
            ),
          ),
          if(discoveredDevices.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Card(
                  child: ListView.builder(
                    itemCount: discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = discoveredDevices[index];
                      return ListTile(
                        title: Text(device.name?.isEmpty ?? true
                            ? '알 수 없는 디바이스'
                            : device.name!),
                        subtitle: Text(device.address),
                        trailing: device.isPaired
                            ? const Icon(Icons.link, color: Colors.green)
                            : null,
                        onTap: () async {
                          try {
                            final service = ref.read(bluetoothServiceProvider);
                            _addLog('${device.name}에 연결 시도 중...');
                            await service.connect(device);
                            _addLog('${device.name}에 연결 성공');
                          } catch (e) {
                            _addLog('연결 오류: $e');
                          }
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

          // 메시지 전송 UI (화면 하단으로 이동)
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            final service = ref.read(bluetoothServiceProvider);
            _addLog('기기 스캔 시작...');
            ref.read(discoveredDevicesProvider.notifier).state = [];
            await service.startScan();
          } catch (e) {
            _addLog('스캔 오류: $e');
          }
        },
        tooltip: '디바이스 스캔',
        child: const Icon(Icons.search),
      ),
    );
  }
}
