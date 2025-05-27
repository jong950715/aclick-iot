import 'dart:async';
import 'package:fpdart/fpdart.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/services/console_manager.dart';
import 'package:permission_handler/permission_handler.dart';

/// 블루투스 연결 상태를 저장하는 Provider
final bluetoothConnectionProvider = StateProvider<bool>((ref) => false);

/// 선택된 디바이스를 저장하는 Provider
final selectedDeviceProvider = StateProvider<BluetoothDevice?>((ref) => null);

mixin BluetoothConnectViewParts<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final BluetoothService _bluetoothService = BluetoothService();
  late final BluetoothProtocolHandler _protocolHandler;
  List<BluetoothDevice> _pairedDevices = [];
  StreamSubscription? _dataSubscription;
  bool _isScanning = false;
  late void Function (Map<String, dynamic> data) _handleWifiCredentials;

  /// Bluetooth 초기화
  void initBluetooth({required void Function (Map<String, dynamic> data) handleWifiCredentials}) async {
    _handleWifiCredentials = handleWifiCredentials;
    await _initBluetooth();
  }
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


  List<Widget> buildBluetoothSection() {
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final isConnected = ref.watch(bluetoothConnectionProvider);
    return [ if (isConnected) ...[
      // 연결된 상태 UI
      Card(
        child: Padding(
          padding:
          const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
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
            ],
          ),
        ),
      ),
    ] else
      ...[
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
            color: Theme
                .of(context)
                .cardColor,
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
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
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
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
    ];
  }

  /// 선택한 장치에 연결
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _addMessage('Connecting to ${device.name ?? device.address}...');

      // 연결 시도
      final BluetoothConnection connection = await _bluetoothService.connect(device);

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

  void _addMessage(String message) {
    ref.read(consoleProvider.notifier).addLog(message);
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
}