import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core/core.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:fpdart/fpdart.dart';

/// 블루투스 연결 상태를 저장하는 Provider
final bluetoothConnectionProvider = StateProvider<bool>((ref) => false);

/// 메시지 기록을 저장하는 Provider
final messagesProvider = StateProvider<List<String>>((ref) => []);

/// 선택된 디바이스를 저장하는 Provider
final selectedDeviceProvider = StateProvider<BluetoothDevice?>((ref) => null);

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

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _dataSubscription?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  /// Bluetooth 초기화
  Future<void> _initBluetooth() async {
    try {
      // 블루투스 초기화
      final result = await _bluetoothService.initializeAdapter();
      if (!result) {
        _addMessage('Bluetooth unavailable');
        return;
      }

      // Custom UUID 설정 - Core 패키지의 상수 사용
      await _bluetoothService.setCustomUuid(BLUETOOTH_IOT_UUID);
      _addMessage('Using UUID: $BLUETOOTH_IOT_UUID');

      // 블루투스 활성화 요청
      if (!(await _bluetoothService.isEnabled())) {
        final enabled = await _bluetoothService.requestEnable();
        if (!enabled) {
          _addMessage('Please enable Bluetooth');
          return;
        }
      }

      // 권한 요청
      final hasPermissions = await _bluetoothService.requestPermissions();
      if (!hasPermissions) {
        _addMessage('Bluetooth permissions denied');
        return;
      }

      _protocolHandler = BluetoothProtocolHandler.fromConnectionStream(
          _bluetoothService.connectionStream);

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
        (l) => _addMessage(l),
        (r) => _addMessage(r.toString()),
      ),
    );
  }

  void _handleReceive(List<int> data) {
    try {
      final message = utf8.decode(data);
      _addMessage('Received: $message');
    } catch (e) {
      _addMessage('Error decoding message: $e');
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

  /// 메시지 전송
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      final data = utf8.encode(message);
      await _protocolHandler.sendHandshake(deviceId: "deviceId", deviceName: "deviceName");
      // await _bluetoothService.sendData(data);
      _addMessage('Sent: $message');
      _messageController.clear();
    } catch (e) {
      _addMessage('Send error: $e');
    }
  }

  /// 메시지 추가
  void _addMessage(String message) {
    ref.read(messagesProvider.notifier).state = [
      ...ref.read(messagesProvider),
      message,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = ref.watch(bluetoothConnectionProvider);
    final messages = ref.watch(messagesProvider);
    final selectedDevice = ref.watch(selectedDeviceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Bluetooth Connect'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(messages[index]),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isConnected) ...[
                  // 연결된 상태 UI
                  Text(
                    'Connected to: ${selectedDevice?.name ?? selectedDevice?.address ?? 'Unknown device'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Enter message',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _sendMessage,
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _disconnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Disconnect'),
                  ),
                ] else ...[
                  // 연결되지 않은 상태 UI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _isScanning ? null : _startScan,
                        child: Text(
                            _isScanning ? 'Scanning...' : 'Scan for Devices'),
                      ),
                      ElevatedButton(
                        onPressed: _loadPairedDevices,
                        child: const Text('Refresh Paired'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Paired Devices:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _pairedDevices.isEmpty
                        ? const Center(child: Text('No paired devices found'))
                        : ListView.builder(
                            itemCount: _pairedDevices.length,
                            itemBuilder: (context, index) {
                              final device = _pairedDevices[index];
                              return ListTile(
                                title: Text(device.name ?? 'Unknown Device'),
                                subtitle: Text(device.address),
                                trailing: ElevatedButton(
                                  onPressed: () => _connectToDevice(device),
                                  child: const Text('Connect'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
