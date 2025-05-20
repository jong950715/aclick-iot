import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:fpdart/fpdart.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';

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

class BluetoothTestScreen extends ConsumerStatefulWidget {
  const BluetoothTestScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BluetoothTestScreen> createState() =>
      _BluetoothTestScreenState();
}

class _BluetoothTestScreenState extends ConsumerState<BluetoothTestScreen> {
  final List<StreamSubscription> _subscriptions = [];
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _ssidController.dispose();
    _passwordController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _initBluetooth() async {
    final service = ref.read(bluetoothServiceProvider);
    final protocolHandler = ref.read(bluetoothProtocolHandlerProvider);

    try {
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
      final service = ref.read(bluetoothServiceProvider);
      final listening =
          await service.listenUsingRfcomm(uuid: BLUETOOTH_IOT_UUID);
      _addLog('Listen 모드 ${listening ? '시작됨' : '실패'}');
    } catch (e) {
      _addLog('Listen 오류: $e');
    }
  }

  void _startHotspot() async {
    // TODO: 핫스팟 활성화 구현
    _addLog('핫스팟 시작 기능은 아직 구현되지 않았습니다.');
  }

  void _sendWifiCredentials() async {
    await ref.read(bluetoothProtocolHandlerProvider).sendWifiCredentials(ssid: 'ssid namename', password: 'password pass');
    return;
    try {
      final service = ref.read(bluetoothServiceProvider);
      final connectionState = ref.read(connectionStateProvider);

      if (connectionState != BluetoothConnectionState.connected &&
          connectionState != BluetoothConnectionState.transferring) {
        _addLog('연결된 디바이스가 없습니다.');
        return;
      }

      final ssid = _ssidController.text;
      final password = _passwordController.text;

      if (ssid.isEmpty) {
        _addLog('SSID를 입력해주세요.');
        return;
      }

      final credentials = {
        'type': 'wifi_credentials',
        'ssid': ssid,
        'password': password,
      };

      final json = jsonEncode(credentials);
      final data = utf8.encode(json);

      // BluetoothService의 sendData 메서드 사용
      final success = await service.sendData(data);
      _addLog('WiFi 자격 증명 전송 ${success ? '성공' : '실패'}');
    } catch (e) {
      _addLog('WiFi 자격 증명 전송 오류: $e');
    }
  }

  void _startServer() async {
    // TODO: HTTP 서버 구현
    _addLog('HTTP 서버 시작 기능은 아직 구현되지 않았습니다.');
  }

  // 블루투스를 통해 텍스트 메시지 전송
  void _sendMessage() async {
    final service = ref.read(bluetoothServiceProvider);
    final connectionState = ref.read(connectionStateProvider);

    if (connectionState != BluetoothConnectionState.connected &&
        connectionState != BluetoothConnectionState.transferring) {
      _addLog('연결된 디바이스가 없습니다.');
      return;
    }

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      return;
    }

    try {
      // BluetoothService의 sendText 메서드 사용
      final success = await service.sendText(message);
      _addLog('메시지 전송 ${success ? '성공' : '실패'}: $message');
      _messageController.clear();
    } catch (e) {
      _addLog('메시지 전송 오류: $e');
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
    final logs = ref.watch(logProvider);

    final isConnected = connectionState == BluetoothConnectionState.connected ||
        connectionState == BluetoothConnectionState.transferring;

    return Scaffold(
      appBar: AppBar(
        title: const Text('A-Click IoT 테스트'),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startListening,
                    child: const Text('1. Listen 시작'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected ? _startHotspot : null,
                    child: const Text('2. Hotspot 시작'),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _ssidController,
              decoration: const InputDecoration(
                labelText: 'SSID',
                border: OutlineInputBorder(),
              ),
              enabled: isConnected,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: isConnected,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected ? _sendWifiCredentials : null,
                    child: const Text('3. SSID/PW 송신'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isConnected ? _startServer : null,
                    child: const Text('4. Server 열기'),
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

          if (discoveredDevices.isNotEmpty)
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('블루투스 메시지 전송',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              labelText: '메시지',
                              border: OutlineInputBorder(),
                              hintText: '전송할 메시지 입력',
                            ),
                            enabled: isConnected,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: isConnected ? _sendMessage : null,
                          icon: const Icon(Icons.send),
                          tooltip: '메시지 전송',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
