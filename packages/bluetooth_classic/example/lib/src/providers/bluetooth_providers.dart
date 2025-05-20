import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'dart:core';
import 'package:rxdart/rxdart.dart';  // RxDart 추가
/// BluetoothService 인스턴스 제공자
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  
  // Provider가 삭제될 때 리소스 정리
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// 블루투스 어댑터 상태 스트림 제공자
final bluetoothAdapterStateProvider = StreamProvider<BluetoothAdapterState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.adapterStateChanges;
});

/// 블루투스 스캔 상태 제공자
final isScanningProvider = StateProvider<bool>((ref) => false);

/// 페어링된 디바이스 목록 제공자
final pairedDevicesProvider = FutureProvider<List<BluetoothDevice>>((ref) async {
  final service = ref.watch(bluetoothServiceProvider);
  try {
    return await service.getPairedDevices();
  } catch (e) {
    return [];
  }
});

/// 발견된 디바이스 제공자 (스캔 시 실시간 업데이트)
final discoveredDevicesProvider = StateNotifierProvider<DiscoveredDevicesNotifier, List<BluetoothDevice>>((ref) {
  final notifier = DiscoveredDevicesNotifier();
  final service = ref.watch(bluetoothServiceProvider);
  
  // 디바이스 발견 스트림 수신 설정
  service.discoveredDevices.listen((device) {
    notifier.addDevice(device);
  });
  
  return notifier;
});

/// 발견된 디바이스 관리를 위한 상태 알림기
class DiscoveredDevicesNotifier extends StateNotifier<List<BluetoothDevice>> {
  DiscoveredDevicesNotifier() : super([]);
  
  /// 목록 초기화
  void clearDevices() {
    state = [];
  }
  
  /// 새 디바이스 추가 또는 기존 디바이스 업데이트
  void addDevice(BluetoothDevice device) {
    // 이미 목록에 있는지 확인
    final index = state.indexWhere((d) => d.address == device.address);
    
    if (index >= 0) {
      // 기존 디바이스 업데이트
      final updatedList = [...state];
      updatedList[index] = device;
      state = updatedList;
    } else {
      // 새 디바이스 추가
      state = [...state, device];
    }
  }
  
  /// 장치 제거
  void removeDevice(String address) {
    state = state.where((d) => d.address != address).toList();
  }
}

/// 현재 선택한 디바이스 제공자
final selectedDeviceProvider = StateProvider<BluetoothDevice?>((ref) => null);

/// 현재 연결 제공자
final bluetoothConnectionProvider = StateProvider<BluetoothConnection?>((ref) => null);

/// 연결 상태 스트림 제공자
final bluetoothConnectionStateProvider = StreamProvider.autoDispose<BluetoothConnectionState>((ref) {
  final connection = ref.watch(bluetoothConnectionProvider);
  
  if (connection == null) {
    // 연결이 없는 경우 디폴트 값으로 'disconnected' 반환
    return Stream.value(BluetoothConnectionState.disconnected);
  }
  
  // 이미 연결되어 있는 경우 현재 상태 확인
  final initialState = connection.isConnected 
      ? BluetoothConnectionState.connected 
      : BluetoothConnectionState.disconnected;
  
  // RxDart의 startWith를 사용하여 초기 상태 제공 + 이후 스트림 이벤트 구독
  // 이것은 Stream.value().followedBy()보다 더 안정적인 방법입니다
  return connection.stateStream.startWith(initialState);
});

/// 수신된 데이터 스트림 제공자
final receivedDataProvider = StreamProvider<List<int>>((ref) {
  final connection = ref.watch(bluetoothConnectionProvider);
  if (connection == null) {
    // 연결이 없는 경우 빈 스트림 반환
    return const Stream.empty();
  }
  // dataStream이 올바른 getter 이름입니다 (receivedData가 아님)
  return connection.dataStream;
});

/// 수신된 텍스트 스트림 제공자
final receivedTextProvider = StreamProvider<String>((ref) {
  final connection = ref.watch(bluetoothConnectionProvider);
  if (connection == null) {
    // 연결이 없는 경우 빈 스트림 반환
    return const Stream.empty();
  }
  // BluetoothConnection에서는 텍스트 스트림을 제공하지 않으니 데이터 스트림을 변환해야 합니다
  return connection.dataStream.map((data) => String.fromCharCodes(data));
});
