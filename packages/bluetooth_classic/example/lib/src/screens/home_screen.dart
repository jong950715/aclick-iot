import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import '../providers/bluetooth_providers.dart';
import 'device_discovery_screen.dart';
import 'connection_screen.dart';
import 'data_transfer_screen.dart';

/// 애플리케이션의 메인 화면으로, 블루투스 기능의 개요와 주요 기능으로 이동하는 탐색 메뉴를 제공합니다.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isInitializing = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  /// 블루투스 어댑터 초기화 및 권한 확인
  Future<void> _initializeBluetooth() async {
    try {
      final BluetoothService bluetoothService = ref.read(bluetoothServiceProvider);
      final initialized = await bluetoothService.initializeAdapter();
      
      if (!initialized) {
        // 자동으로 활성화 요청
        await bluetoothService.requestEnable();
      }
      
      // 권한 확인
      final hasPermissions = await bluetoothService.requestEnable();
      if (!hasPermissions) {
        setState(() {
          _errorMessage = '블루투스 권한이 필요합니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '블루투스 초기화 오류: $e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 블루투스 어댑터 상태 감시
    final adapterState = ref.watch(bluetoothAdapterStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Classic 예제'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAboutDialog(context),
            tooltip: '정보',
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(adapterState),
    );
  }

  /// 블루투스 상태에 따른 콘텐츠 구성
  Widget _buildContent(AsyncValue<BluetoothAdapterState> adapterState) {
    // 오류 메시지가 있는 경우 표시
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeBluetooth,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return adapterState.when(
      data: (state) {
        if (state != BluetoothAdapterState.enabled) {
          return _buildBluetoothDisabledView(state);
        }
        return _buildFeatureGrid();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('블루투스 상태 확인 오류: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeBluetooth,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  /// 블루투스가 비활성화된 경우 표시할 화면
  Widget _buildBluetoothDisabledView(BluetoothAdapterState state) {
    IconData icon;
    String message;
    
    switch (state) {
      case BluetoothAdapterState.disabled:
        icon = Icons.bluetooth_disabled;
        message = '블루투스가 비활성화되어 있습니다.';
        break;
      case BluetoothAdapterState.unauthorized:
        icon = Icons.no_accounts;
        message = '블루투스 권한이 필요합니다.';
        break;
      case BluetoothAdapterState.unsupported:
        icon = Icons.error_outline;
        message = '이 기기는 블루투스를 지원하지 않습니다.';
        break;
      case BluetoothAdapterState.turningOn:
        icon = Icons.bluetooth_searching;
        message = '블루투스 활성화 중...';
        break;
      case BluetoothAdapterState.turningOff:
        icon = Icons.bluetooth_disabled;
        message = '블루투스 비활성화 중...';
        break;
      default:
        icon = Icons.bluetooth_disabled;
        message = '블루투스 상태를 확인할 수 없습니다.';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 24),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (state == BluetoothAdapterState.disabled)
            ElevatedButton(
              onPressed: () async {
                final bluetoothService = ref.read(bluetoothServiceProvider);
                await bluetoothService.requestEnable();
              },
              child: const Text('블루투스 활성화'),
            ),
        ],
      ),
    );
  }

  /// 주요 기능 그리드 화면 구성
  Widget _buildFeatureGrid() {
    // 주요 기능 목록
    final features = [
      {
        'title': '기기 검색',
        'description': '주변의 블루투스 장치를 검색하고 페어링 상태를 관리합니다.',
        'icon': Icons.search,
        'color': Colors.blue,
        'onTap': () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DeviceDiscoveryScreen()),
        ),
      },
      {
        'title': '연결 관리',
        'description': '선택한 블루투스 장치에 연결하고 연결 상태를 모니터링합니다.',
        'icon': Icons.bluetooth_connected,
        'color': Colors.green,
        'onTap': () {
          final selectedDevice = ref.read(selectedDeviceProvider);
          if (selectedDevice == null) {
            _showDeviceSelectionDialog();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ConnectionScreen()),
          );
        },
      },
      {
        'title': '데이터 전송',
        'description': '연결된 장치와 데이터를 주고 받습니다.',
        'icon': Icons.swap_horiz,
        'color': Colors.orange,
        'onTap': () {
          final connection = ref.read(bluetoothConnectionProvider);
          if (connection == null || !connection.isConnected) {
            _showConnectionRequiredDialog();
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DataTransferScreen()),
          );
        },
      },
      {
        'title': '블루투스 정보',
        'description': '블루투스 어댑터 상태 및 장치 정보를 확인합니다.',
        'icon': Icons.info,
        'color': Colors.purple,
        'onTap': () => _showBluetoothInfoDialog(),
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '블루투스 클래식 기능',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatusCard(),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.9,
          ),
          itemCount: features.length,
          itemBuilder: (context, index) {
            final feature = features[index];
            return _buildFeatureCard(
              title: feature['title'] as String,
              description: feature['description'] as String,
              icon: feature['icon'] as IconData,
              color: feature['color'] as Color,
              onTap: feature['onTap'] as VoidCallback,
            );
          },
        ),
      ],
    );
  }

  /// 블루투스 상태 카드 위젯
  Widget _buildStatusCard() {
    final adapterState = ref.watch(bluetoothAdapterStateProvider).value ?? BluetoothAdapterState.unknown;
    final selectedDevice = ref.watch(selectedDeviceProvider);
    final connection = ref.watch(bluetoothConnectionProvider);

    Color statusColor;
    switch (adapterState) {
      case BluetoothAdapterState.enabled:
        statusColor = Colors.green;
        break;
      case BluetoothAdapterState.disabled:
        statusColor = Colors.red;
        break;
      case BluetoothAdapterState.turningOn:
      case BluetoothAdapterState.turningOff:
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bluetooth, color: statusColor),
                const SizedBox(width: 8),
                Text(
                  '블루투스 상태',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getAdapterStateText(adapterState),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (selectedDevice != null) ...[
              Row(
                children: [
                  const Icon(Icons.devices, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('선택된 기기', style: Theme.of(context).textTheme.labelLarge),
                        Text(
                          selectedDevice.name ?? '이름 없음',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          selectedDevice.address,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(),
            ],
            Row(
              children: [
                Icon(
                  connection?.isConnected == true
                      ? Icons.link
                      : Icons.link_off,
                  color: connection?.isConnected == true ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  '연결 상태',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const Spacer(),
                Text(
                  connection?.isConnected == true
                      ? '연결됨'
                      : '연결 안됨',
                  style: TextStyle(
                    color: connection?.isConnected == true ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 기능 카드 위젯 생성
  Widget _buildFeatureCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 어댑터 상태 텍스트 반환
  String _getAdapterStateText(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.enabled:
        return '활성화됨';
      case BluetoothAdapterState.disabled:
        return '비활성화됨';
      case BluetoothAdapterState.unauthorized:
        return '권한 없음';
      case BluetoothAdapterState.turningOn:
        return '활성화 중';
      case BluetoothAdapterState.turningOff:
        return '비활성화 중';
      case BluetoothAdapterState.unsupported:
        return '지원 안 함';
      default:
        return '알 수 없음';
    }
  }

  /// 기기 선택 다이얼로그 표시
  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('기기 선택 필요'),
        content: const Text('연결 관리 기능을 사용하려면 먼저 블루투스 기기를 선택해주세요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DeviceDiscoveryScreen()),
              );
            },
            child: const Text('기기 검색으로 이동'),
          ),
        ],
      ),
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
              
              final selectedDevice = ref.read(selectedDeviceProvider);
              if (selectedDevice == null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DeviceDiscoveryScreen()),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ConnectionScreen()),
                );
              }
            },
            child: const Text('연결 화면으로 이동'),
          ),
        ],
      ),
    );
  }

  /// 블루투스 정보 다이얼로그 표시
  void _showBluetoothInfoDialog() {
    final adapterState = ref.read(bluetoothAdapterStateProvider).value ?? BluetoothAdapterState.unknown;
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.bluetooth_searching, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('블루투스 정보'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('어댑터 상태', _getAdapterStateText(adapterState)),
              const Divider(),
              Consumer(
                builder: (context, ref, _) {
                  final pairedDevices = ref.watch(pairedDevicesProvider);
                  return _infoRow(
                    '페어링된 기기',
                    pairedDevices.when(
                      data: (devices) => devices.length.toString(),
                      loading: () => '로딩 중...',
                      error: (_, __) => '알 수 없음',
                    ),
                  );
                },
              ),
              const Divider(),
              Consumer(
                builder: (context, ref, _) {
                  final selectedDevice = ref.watch(selectedDeviceProvider);
                  return _infoRow(
                    '선택된 기기',
                    selectedDevice?.name ?? '없음',
                  );
                },
              ),
              const Divider(),
              Consumer(
                builder: (context, ref, _) {
                  final connection = ref.watch(bluetoothConnectionProvider);
                  return _infoRow(
                    '연결 상태',
                    connection?.isConnected == true ? '연결됨' : '연결 안됨',
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final bluetoothService = ref.read(bluetoothServiceProvider);
                await bluetoothService.requestEnable();
              },
              child: const Text('블루투스 설정'),
            ),
          ],
        );
      },
    );
  }

  /// 정보 표시용 행 위젯
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  /// 앱 정보 다이얼로그 표시
  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AboutDialog(
        applicationName: 'Bluetooth Classic 예제',
        applicationVersion: 'v1.0.0',
        applicationIcon: const FlutterLogo(size: 48),
        applicationLegalese: '© 2025 AClick. All rights reserved.',
        children: [
          const SizedBox(height: 16),
          const Text(
            'bluetooth_classic 패키지의 기능을 시연하는 예제 애플리케이션입니다. 블루투스 디바이스 검색, 연결, 데이터 전송 등의 기능을 체험해보세요.',
            style: TextStyle(fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
