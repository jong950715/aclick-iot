import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/bluetooth_providers.dart';
import 'data_transfer_screen.dart';

/// 블루투스 연결 관리 화면
/// 선택한 디바이스에 연결하고 연결 상태를 모니터링합니다.
class ConnectionScreen extends ConsumerStatefulWidget {
  const ConnectionScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends ConsumerState<ConnectionScreen> {
  String? _errorMessage;
  bool _isConnecting = false;
  bool _isDisconnecting = false;

  @override
  void initState() {
    super.initState();
    _checkConnectionStatus();
  }

  /// 현재 연결 상태 확인
  void _checkConnectionStatus() {
    final connection = ref.read(bluetoothConnectionProvider);
    if (connection == null) {
      // 연결이 없는 경우 자동으로 연결 시도
      _connectToDevice();
    }
  }

  /// 선택한 디바이스에 연결
  Future<void> _connectToDevice() async {
    final selectedDevice = ref.read(selectedDeviceProvider);
    if (selectedDevice == null) {
      setState(() {
        _errorMessage = '연결할 디바이스가 선택되지 않았습니다.';
      });
      return;
    }

    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    try {
      final bluetoothService = ref.read(bluetoothServiceProvider);
      
      // 연결 설정
      final connectionConfig = ConnectionConfig(
        autoReconnect: true,
        connectionTimeout: 15000,
      );
      
      // 디바이스에 연결
      final connection = await bluetoothService.connect(
        selectedDevice,
        config: connectionConfig,
      );
      
      // 연결 상태 업데이트
      ref.read(bluetoothConnectionProvider.notifier).state = connection;
      
    } catch (e) {
      setState(() {
        _errorMessage = '연결 실패: $e';
      });
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  /// 연결 종료
  Future<void> _disconnectFromDevice() async {
    final connection = ref.read(bluetoothConnectionProvider);
    if (connection == null) {
      return;
    }

    setState(() {
      _isDisconnecting = true;
      _errorMessage = null;
    });

    try {
      await connection.disconnect();
      ref.read(bluetoothConnectionProvider.notifier).state = null;
    } catch (e) {
      setState(() {
        _errorMessage = '연결 해제 실패: $e';
      });
    } finally {
      setState(() {
        _isDisconnecting = false;
      });
    }
  }

  /// 데이터 전송 화면으로 이동
  void _navigateToDataTransfer() {
    final connection = ref.read(bluetoothConnectionProvider);
    if (connection == null || !connection.isConnected) {
      _showConnectionRequiredDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DataTransferScreen()),
    );
  }

  /// 연결 필요 다이얼로그 표시
  void _showConnectionRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('연결 필요'),
        content: const Text('데이터 전송 기능을 사용하려면 먼저 블루투스 기기에 연결해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _connectToDevice();
            },
            child: const Text('연결하기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final connection = ref.watch(bluetoothConnectionProvider);
    final bluetoothConnectionState = ref.watch(bluetoothConnectionStateProvider);
    
    if (selectedDevice == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('연결 관리'),
        ),
        body: const Center(
          child: Text('연결할 디바이스가 선택되지 않았습니다.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('연결 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: '데이터 전송',
            onPressed: connection?.isConnected == true ? _navigateToDataTransfer : null,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 선택된 디바이스 정보 카드
            _buildDeviceInfoCard(selectedDevice),
            
            const SizedBox(height: 24),
            
            // 연결 상태 표시
            _buildConnectionStatusCard(bluetoothConnectionState),
            
            const SizedBox(height: 16),
            
            // 오류 메시지
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),
              
            const SizedBox(height: 24),
            
            // 연결 관리 버튼
            if (connection?.isConnected != true && !_isConnecting)
              ElevatedButton.icon(
                onPressed: _connectToDevice,
                icon: const Icon(Icons.bluetooth_connected),
                label: const Text('연결하기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            else if (_isConnecting)
              ElevatedButton.icon(
                onPressed: null,
                icon: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                label: Text('연결 중...'),
              )
            else if (connection?.isConnected == true && !_isDisconnecting)
              ElevatedButton.icon(
                onPressed: _disconnectFromDevice,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('연결 해제'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            else if (_isDisconnecting)
              ElevatedButton.icon(
                onPressed: null,
                icon: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                label: Text('연결 해제 중...'),
              ),
              
            const SizedBox(height: 16),
            
            // 데이터 전송 화면으로 이동 버튼 (연결된 경우에만 활성화)
            OutlinedButton.icon(
              onPressed: connection?.isConnected == true ? _navigateToDataTransfer : null,
              icon: const Icon(Icons.send),
              label: const Text('데이터 전송 시작'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 디바이스 정보 카드 위젯
  Widget _buildDeviceInfoCard(BluetoothDevice device) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    color: Colors.blue.shade700,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name ?? '이름 없는 기기',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device.address,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: device.isPaired ? Colors.green.shade50 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    device.isPaired ? '페어링됨' : '페어링 안됨',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: device.isPaired ? Colors.green.shade700 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildDeviceInfoRow('신호 강도', device.rssi != null ? '${device.rssi} dBm' : '알 수 없음'),
            const SizedBox(height: 8),
            _buildDeviceInfoRow(
              '장치 클래스',
              device.deviceClass != 0
                  ? '0x${device.deviceClass.toRadixString(16).padLeft(4, '0')}'
                  : '알 수 없음',
            ),
            const SizedBox(height: 8),
            _buildDeviceInfoRow('주소 유형', 'MAC'),
            const SizedBox(height: 8),
            _buildDeviceInfoRow('연결 타입', 'Bluetooth Classic (BR/EDR)'),
          ],
        ),
      ),
    );
  }

  /// 정보 행 위젯
  Widget _buildDeviceInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 연결 상태 카드 위젯
  Widget _buildConnectionStatusCard(AsyncValue<BluetoothConnectionState> bluetoothConnectionState) {
    return bluetoothConnectionState.when(
      data: (state) {
        Color statusColor;
        String statusText;
        IconData statusIcon;
        
        switch (state) {
          case BluetoothConnectionState.connected:
            statusColor = Colors.green;
            statusText = '연결됨';
            statusIcon = Icons.bluetooth_connected;
            break;
          case BluetoothConnectionState.connecting:
            statusColor = Colors.blue;
            statusText = '연결 중...';
            statusIcon = Icons.bluetooth_searching;
            break;
          case BluetoothConnectionState.disconnecting:
            statusColor = Colors.orange;
            statusText = '연결 해제 중...';
            statusIcon = Icons.bluetooth_disabled;
            break;
          case BluetoothConnectionState.disconnected:
          default:
            statusColor = Colors.grey;
            statusText = '연결 안됨';
            statusIcon = Icons.bluetooth_disabled;
            break;
        }
        
        return Card(
          elevation: 1,
          color: statusColor.withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '연결 상태',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Card(
        elevation: 1,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('연결 상태 확인 중...'),
            ],
          ),
        ),
      ),
      error: (error, _) => Card(
        elevation: 1,
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '연결 상태 오류',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.toString(),
                      style: TextStyle(
                        color: Colors.red.shade700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
