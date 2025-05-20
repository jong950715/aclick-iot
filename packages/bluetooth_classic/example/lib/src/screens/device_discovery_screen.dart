import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import '../providers/bluetooth_providers.dart';
import 'connection_screen.dart';

/// 블루투스 디바이스 검색 화면. 주변 블루투스 장치를 검색하고 표시합니다.
class DeviceDiscoveryScreen extends ConsumerStatefulWidget {
  const DeviceDiscoveryScreen({super.key});

  @override
  ConsumerState<DeviceDiscoveryScreen> createState() => _DeviceDiscoveryScreenState();
}

class _DeviceDiscoveryScreenState extends ConsumerState<DeviceDiscoveryScreen> {
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPairedDevices();
    });
  }

  /// 페어링된 디바이스 목록 로드
  Future<void> _loadPairedDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 페어링 기기 로드를 위해 pairedDevicesProvider 갱신 요청
      ref.invalidate(pairedDevicesProvider);
    } catch (e) {
      setState(() {
        _errorMessage = '페어링된 기기 로드 오류: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 스캔 시작 메서드
  Future<void> _startScan() async {
    final isScanningNotifier = ref.read(isScanningProvider.notifier);
    final bluetoothService = ref.read(bluetoothServiceProvider);
    final devicesNotifier = ref.read(discoveredDevicesProvider.notifier);
    
    // 기존 발견 기기 목록 초기화
    devicesNotifier.clearDevices();
    
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    
    try {
      // 스캔 시작
      final success = await bluetoothService.startScan();
      
      if (success) {
        isScanningNotifier.state = true;
      } else {
        setState(() {
          _errorMessage = '블루투스 스캔을 시작할 수 없습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '스캔 시작 오류: $e';
      });
      isScanningNotifier.state = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 스캔 중지 메서드
  Future<void> _stopScan() async {
    final isScanningNotifier = ref.read(isScanningProvider.notifier);
    final bluetoothService = ref.read(bluetoothServiceProvider);
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      await bluetoothService.stopScan();
      isScanningNotifier.state = false;
    } catch (e) {
      setState(() {
        _errorMessage = '스캔 중지 오류: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 디바이스 선택 처리
  void _selectDevice(BluetoothDevice device) {
    // 선택된 디바이스 상태 업데이트
    ref.read(selectedDeviceProvider.notifier).state = device;
    
    // 연결 화면으로 이동
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ConnectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 블루투스 상태, 스캔 상태, 기기 목록 관찰
    final adapterState = ref.watch(bluetoothAdapterStateProvider).value;
    final isScanning = ref.watch(isScanningProvider);
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final pairedDevices = ref.watch(pairedDevicesProvider);
    
    final isBluetoothEnabled = adapterState == BluetoothAdapterState.enabled;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('디바이스 검색'),
        actions: [
          if (isBluetoothEnabled)
            IconButton(
              icon: Icon(isScanning ? Icons.stop : Icons.refresh),
              tooltip: isScanning ? '스캔 중지' : '스캔 시작',
              onPressed: isScanning ? _stopScan : _startScan,
            ),
        ],
      ),
      body: Column(
        children: [
          // 어댑터 상태 표시
          Container(
            padding: const EdgeInsets.all(8.0),
            color: _getStatusColor(adapterState ?? BluetoothAdapterState.unknown),
            width: double.infinity,
            child: Text(
              _getStatusMessage(adapterState ?? BluetoothAdapterState.unknown),
              style: TextStyle(
                color: _getStatusTextColor(adapterState ?? BluetoothAdapterState.unknown),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // 오류 메시지
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade800),
              ),
            ),
            
          // 스캔 상태 표시
          if (isScanning)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          
          if (!isBluetoothEnabled)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bluetooth_disabled,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '블루투스가 비활성화 상태입니다',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        final bluetoothService = ref.read(bluetoothServiceProvider);
                        bluetoothService.requestEnable();
                      },
                      child: const Text('블루투스 활성화'),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: pairedDevices.when(
                data: (pairedList) {
                  if (pairedList.isEmpty && discoveredDevices.isEmpty) {
                    return Center(
                      child: isScanning
                          ? const Text('기기 검색 중...')
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.bluetooth_searching,
                                  size: 48,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text('발견된 기기가 없습니다'),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _startScan,
                                  child: const Text('기기 검색 시작'),
                                ),
                              ],
                            ),
                    );
                  }
                  
                  return RefreshIndicator(
                    onRefresh: _loadPairedDevices,
                    child: ListView(
                      children: [
                        if (pairedList.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              '페어링된 기기',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...pairedList.map((device) => _buildDeviceListTile(device)),
                          const Divider(),
                        ],
                    
                        if (discoveredDevices.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              '발견된 기기',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...(discoveredDevices.toList()
                            ..sort((a, b) => (b.rssi ?? -100).compareTo(a.rssi ?? -100)))
                            .map((device) => _buildDeviceListTile(device)),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('기기 목록 로드 오류: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPairedDevices,
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: isBluetoothEnabled && !isScanning
          ? FloatingActionButton(
              onPressed: _startScan,
              tooltip: '검색 시작',
              child: const Icon(Icons.search),
            )
          : null,
    );
  }
  
  /// 기기 목록 항목 빌더
  Widget _buildDeviceListTile(BluetoothDevice device) {
    // RSSI 값을 기반으로 신호 강도 아이콘 생성
    Widget signalIcon;
    if (device.rssi != null) {
      if (device.rssi! > -60) {
        signalIcon = const Icon(Icons.signal_cellular_4_bar, color: Colors.green);
      } else if (device.rssi! > -70) {
        signalIcon = const Icon(Icons.signal_cellular_alt, color: Colors.lightGreen);
      } else if (device.rssi! > -80) {
        signalIcon = const Icon(Icons.signal_cellular_alt_2_bar, color: Colors.orange);
      } else {
        signalIcon = const Icon(Icons.signal_cellular_alt_1_bar, color: Colors.red);
      }
    } else {
      signalIcon = const Icon(Icons.signal_cellular_0_bar, color: Colors.grey);
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.bluetooth,
          color: device.isPaired ? Colors.blue : Colors.grey,
        ),
        title: Text(
          device.name ?? '이름 없는 기기',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.address),
            if (device.rssi != null)
              Text('신호 강도: ${device.rssi} dBm'),
            if (device.deviceClass != 0)
              Text('클래스: 0x${device.deviceClass.toRadixString(16).padLeft(4, '0')}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            signalIcon,
            const SizedBox(width: 8),
            if (device.isPaired)
              const Icon(Icons.link, color: Colors.blue, size: 16),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => _selectDevice(device),
        isThreeLine: true,
      ),
    );
  }

  // 블루투스 상태에 따른 색상 반환
  Color _getStatusColor(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.enabled:
        return Colors.green.shade100;
      case BluetoothAdapterState.disabled:
        return Colors.orange.shade100;
      case BluetoothAdapterState.unauthorized:
        return Colors.red.shade100;
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.turningOff:
        return Colors.blue.shade100;
      case BluetoothAdapterState.unsupported:
      case BluetoothAdapterState.unknown:
      default:
        return Colors.grey.shade200;
    }
  }
  
  // 블루투스 상태에 따른 텍스트 색상 반환
  Color _getStatusTextColor(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.enabled:
        return Colors.green.shade800;
      case BluetoothAdapterState.disabled:
        return Colors.orange.shade800;
      case BluetoothAdapterState.unauthorized:
        return Colors.red.shade800;
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.turningOff:
        return Colors.blue.shade800;
      case BluetoothAdapterState.unsupported:
      case BluetoothAdapterState.unknown:
      default:
        return Colors.grey.shade800;
    }
  }
  
  // 블루투스 상태에 따른 메시지 반환
  String _getStatusMessage(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.enabled:
        return '블루투스 활성화됨';
      case BluetoothAdapterState.disabled:
        return '블루투스 비활성화됨';
      case BluetoothAdapterState.unauthorized:
        return '블루투스 권한 없음';
      case BluetoothAdapterState.turningOn:
        return '블루투스 활성화 중...';
      case BluetoothAdapterState.turningOff:
        return '블루투스 비활성화 중...';
      case BluetoothAdapterState.unsupported:
        return '블루투스를 지원하지 않는 기기';
      case BluetoothAdapterState.unknown:
      default:
        return '블루투스 상태 확인 중...';
    }
  }
}
