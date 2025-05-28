import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iot/repositories/app_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:core/core.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';

part 'ble_manager.g.dart';

@riverpod
class BleManager extends _$BleManager {
  /// 라이브러리

  final centralManager = CentralManager();
  late final AppLogger _logger;

  /// 구독 관련

  late final StreamSubscription _discoveredSubscription;
  late final StreamSubscription _stateChangedSubscription;
  late final StreamSubscription _connectionStateChangedSubscription;
  late final StreamSubscription _characteristicNotifiedSubscription;

  /// 객체 관리
  DiscoveredEventArgs? _discovered;
  Peripheral? _peripheral;
  List<GATTService>? _services;
  GATTService? _service;
  List<GATTCharacteristic>? _characteristics;
  GATTCharacteristic? _wifiGatt;
  GATTCharacteristic? _pingGatt;
  GATTCharacteristic? _newEventClipGatt;

  ///상태 관련
  bool _initialized = false;
  bool _isScanning = false;
  bool _isConnected = false;
  ConnectionState _connectionState = ConnectionState.disconnected;

  @override
  Future<void> build() async {
    ref.keepAlive();
    _logger = ref.read(appLoggerProvider.notifier);
    _logger.logInfo('BLE 매니저 빌드 시작');
    return;
  }

  void dispose() {
    _logger.logInfo('BLE 매니저 자원 해제 시작');
    _discoveredSubscription.cancel();
    _stateChangedSubscription.cancel();
    _connectionStateChangedSubscription.cancel();
    _logger.logInfo('BLE 매니저 자원 해제 완료');
  }

  Future<void> initialize() async {
    _logger.logInfo('BLE 매니저 초기화 시작');
    if (_initialized) {
      _logger.logInfo('BLE 매니저가 이미 초기화되어 있음');
      return;
    }
    _initialized = true;
    _logger.logInfo('BLE 매니저 초기화 플래그 설정');

    /// 기본 상태 구독
    _logger.logInfo('BLE 상태 변경 리스너 등록');
    _stateChangedSubscription = centralManager.stateChanged.listen((eventArgs,) async {
      _logger.logInfo('BLE 상태 변경: ${eventArgs.state}');
      print('stateChanged: ${eventArgs.state}');
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        _logger.logInfo('BLE 권한 없음, 권한 요청 시작');
        await centralManager.authorize();
        _logger.logInfo('BLE 권한 요청 완료');
      }
    });

    /// 연결상태 구독
    _logger.logInfo('BLE 연결 상태 변경 리스너 등록');
    _connectionStateChangedSubscription = centralManager.connectionStateChanged
        .listen((PeripheralConnectionStateChangedEventArgs eventArgs) {
          final peripheral = eventArgs.peripheral;
          _logger.logInfo('BLE 연결 상태 변경 감지: ${eventArgs.state}');
          switch (eventArgs.state) {
            case ConnectionState.connected:
              _logger.logInfo('기기에 연결됨: ${peripheral.uuid}');
              _isConnected = true;
              break;
            case ConnectionState.disconnected:
              _logger.logInfo('기기 연결 해제됨: ${peripheral.uuid}');
              _isConnected = false;
              break;
          }
          _connectionState = eventArgs.state;
          _logger.logInfo('BLE 연결 상태 업데이트: $_connectionState');
        });

    /// 발견된 기기 리스너
    _logger.logInfo('BLE 장치 발견 리스너 등록');
    _discoveredSubscription = centralManager.discovered.listen((
      DiscoveredEventArgs discovered,
    ) {
      _logger.logDebug('기기 발견됨: ${discovered.advertisement.name}');
      if (discovered.advertisement.serviceUUIDs.contains(
        UUID.fromString(BLE_SERVICE_UUID),
      )) {
        _logger.logInfo(
          '호환 가능한 주변 기기 발견: ${discovered.advertisement.name} : \n 신호 강도 ${discovered.rssi}',
        );
        _discovered = discovered;
        _peripheral = discovered.peripheral;
        _logger.logInfo('기기 정보 저장 및 스캔 중지');
        stopScan();
      } else {
        _logger.logDebug('호환되지 않는 기기 무시: ${discovered.advertisement.name}');
      }
    });
    _logger.logInfo('BLE 특성 알림 리스너 등록');
    _characteristicNotifiedSubscription = centralManager.characteristicNotified
        .listen((eventArgs) {
          final c = eventArgs.characteristic;
          _logger.logInfo('특성으로부터 데이터 수신: ${eventArgs.value} (특성 UUID: ${c.uuid})');
        });
    print('설정 다 했다.');
    _logger.logInfo('BLE 매니저 초기화 완료');
    return;
  }

  Future<void> scanDuration(Duration duration) async {
    _logger.logInfo('지정된 시간동안 BLE 스캔 시작: ${duration.inSeconds}초');
    await startScan();
    _logger.logInfo('스캔 타이머 설정: ${duration.inSeconds}초');
    await Future.delayed(duration);
    _logger.logInfo('스캔 시간 만료, 스캔 중지');
    await stopScan();
  }

  Future<void> startScan() async {
    _logger.logInfo('BLE 스캔 시작 요청');
    if (_isScanning) {
      _logger.logInfo('이미 스캔 중, 중복 스캔 요청 무시');
      return;
    }
    _isScanning = true;
    _logger.logInfo('스캔 상태 플래그 설정: true');
    _logger.logInfo('BLE 디바이스 검색 시작');
    await centralManager.startDiscovery();
    _logger.logInfo('BLE 디바이스 검색 시작됨');
  }

  Future<void> stopScan() async {
    _logger.logInfo('BLE 스캔 중지 요청');
    if (!_isScanning) {
      _logger.logInfo('스캔 중이 아님, 중지 요청 무시');
      return;
    }
    _isScanning = false;
    _logger.logInfo('스캔 상태 플래그 설정: false');
    _logger.logInfo('BLE 디바이스 검색 중지');
    await centralManager.stopDiscovery();
    _logger.logInfo('BLE 디바이스 검색 중지됨');
  }

  Future<void> connect() async {
    _logger.logInfo('BLE 기기 연결 시도');
    if (_isConnected) {
      _logger.logInfo('이미 연결됨, 중복 연결 요청 무시');
      return;
    }
    _isConnected = true;
    _logger.logInfo('연결 상태 플래그 설정: true');
    final d = _discovered;
    if (d == null) {
      _logger.logWarning('발견된 기기 정보 없음, 연결 취소');
      _logger.logInfo('Discovery not found yet.');
      return;
    }
    final p = d.peripheral;
    _logger.logInfo('연결할 기기: ${p.uuid}');

    /// 연결하기
    _logger.logInfo('BLE 기기에 연결 시작');
    await centralManager.connect(p);
    _logger.logInfo('BLE 기기 연결 성공');
    _logger.logInfo('MTU 크기 요청: 517');
    await centralManager.requestMTU(p, mtu: 517);
    _logger.logInfo('MTU 크기 설정 완료');

    /// service, characteristic 찾기
    _logger.logInfo('GATT 서비스 검색 시작');
    _services = await centralManager.discoverGATT(p);
    _logger.logInfo('발견된 서비스 수: ${_services?.length ?? 0}');
    
    _service =
        _services
            ?.where((s) => s.uuid == UUID.fromString(BLE_SERVICE_UUID))
            .firstOrNull;
    
    if (_service != null) {
      _logger.logInfo('필요한 서비스 발견: ${_service?.uuid}');
    } else {
      _logger.logWarning('필요한 서비스를 찾을 수 없음: ${BLE_SERVICE_UUID}');
    }
    
    _characteristics = _service?.characteristics;
    _logger.logInfo('발견된 특성 수: ${_characteristics?.length ?? 0}');
    
    _wifiGatt =
        _characteristics
            ?.where(
              (c) => c.uuid == UUID.fromString(BLE_GATT_WIFI_UUID),
            ).firstOrNull;
    
    if (_wifiGatt != null) {
      _logger.logInfo('WiFi 특성 발견: ${_wifiGatt?.uuid}');
    } else {
      _logger.logWarning('WiFi 특성을 찾을 수 없음');
    }
    
    _pingGatt =
        _characteristics
            ?.where(
              (c) => c.uuid == UUID.fromString(BLE_GATT_PING_UUID),
            ).firstOrNull;
    
    if (_pingGatt != null) {
      _logger.logInfo('Ping 특성 발견: ${_pingGatt?.uuid}');
    } else {
      _logger.logWarning('Ping 특성을 찾을 수 없음');
    }
    
    _newEventClipGatt =
        _characteristics
            ?.where(
              (c) => c.uuid == UUID.fromString(BLE_GATT_NEW_EVENT_CLIP_UUID),
            ).firstOrNull;
    
    if (_newEventClipGatt != null) {
      _logger.logInfo('이벤트 클립 특성 발견: ${_newEventClipGatt?.uuid}');
    } else {
      _logger.logWarning('이벤트 클립 특성을 찾을 수 없음');
    }

    _logger.logInfo('WiFi 특성 알림 상태 활성화');
    centralManager.setCharacteristicNotifyState(p, _wifiGatt!, state: true);
    _logger.logInfo('BLE 기기 연결 및 설정 완료');
    return;
  }

  Future<void> disconnect() async {
    _logger.logInfo('BLE 기기 연결 해제 요청');
    if (!_isConnected) {
      _logger.logInfo('연결된 상태가 아님, 연결 해제 요청 무시');
      return;
    }
    _isConnected = false;
    _logger.logInfo('연결 상태 플래그 설정: false');
    
    if (_peripheral == null) {
      _logger.logWarning('연결 해제할 기기 정보가 없음');
      return;
    }
    
    _logger.logInfo('기기 연결 해제 시작: ${_peripheral!.uuid}');
    await centralManager.disconnect(_peripheral!);
    _logger.logInfo('기기 연결 해제 완료');
  }

  Future<void> ping() async {
    _logger.logInfo('BLE 기기 Ping 테스트 요청');
    if (_isConnected == false) {
      _logger.logWarning('연결되지 않은 상태, Ping 요청 무시');
      return;
    }
    if (_connectionState == ConnectionState.disconnected) {
      _logger.logWarning('연결 상태가 disconnected, Ping 요청 무시');
      return;
    }

    final p = _discovered?.peripheral;
    final c = _pingGatt;
    if (p == null) {
      _logger.logWarning('Ping 요청할 기기 정보 없음');
      return;
    }
    if (c == null) {
      _logger.logWarning('Ping 특성 정보 없음');
      return;
    }
    
    _logger.logInfo('Ping 데이터 전송 시작: [0x01, 0x02, 0x03]');
    await centralManager.writeCharacteristic(
      p,
      c,
      value: Uint8List.fromList([0x01, 0x02, 0x03]),
      type: GATTCharacteristicWriteType.withResponse,
    );
    _logger.logInfo('Ping 데이터 전송 완료');
  }

  Future<void> sendWifiCredential(HotspotInfo hotspotInfo) async {
    _logger.logInfo('WiFi 핫스팟 정보 전송 시작');
    _logger.logInfo('전송할 핫스팟 정보: SSID=${hotspotInfo.ssid}');
    await _writeJson(hotspotInfo.toJson());
    _logger.logInfo('WiFi 핫스팟 정보 전송 완료');
  }

  Future<void> _writeJson(Map<String, dynamic> json) async {
    _logger.logInfo('JSON 데이터 전송 시작');
    if (_isConnected == false) {
      _logger.logWarning('연결되지 않은 상태, JSON 전송 무시');
      return;
    }
    if (_connectionState == ConnectionState.disconnected) {
      _logger.logWarning('연결 상태가 disconnected, JSON 전송 무시');
      return;
    }

    _logger.logInfo('JSON 변환 및 인코딩');
    final jsonString = jsonEncode(json);
    _logger.logDebug('인코딩된 JSON: $jsonString');
    final data = Uint8List.fromList(utf8.encode(jsonString));
    _logger.logInfo('데이터 크기: ${data.length} 바이트');

    final p = _discovered?.peripheral;
    final c = _wifiGatt;
    if (p == null) {
      _logger.logWarning('JSON 전송할 기기 정보 없음');
      return;
    }
    if (c == null) {
      _logger.logWarning('WiFi 특성 정보 없음');
      return;
    }
    
    _logger.logInfo('JSON 데이터 전송 시작: ${p.uuid}');
    await centralManager.writeCharacteristic(
      p,
      c,
      value: data,
      type: GATTCharacteristicWriteType.withResponse,
    );
    _logger.logInfo('JSON 데이터 전송 완료');
  }

  Future<void> writeNewEventClip(String filename) async {
    _logger.logInfo('새 이벤트 클립 파일명 전송 시작: $filename');
    if (_isConnected == false) {
      _logger.logWarning('연결되지 않은 상태, 이벤트 클립 전송 무시');
      return;
    }
    if (_connectionState == ConnectionState.disconnected) {
      _logger.logWarning('연결 상태가 disconnected, 이벤트 클립 전송 무시');
      return;
    }

    final p = _discovered?.peripheral;
    final c = _newEventClipGatt;
    if (p == null) {
      _logger.logWarning('이벤트 클립 전송할 기기 정보 없음');
      return;
    }
    if (c == null) {
      _logger.logWarning('이벤트 클립 특성 정보 없음');
      return;
    }
    
    _logger.logInfo('이벤트 클립 파일명 전송 시작: $filename');
    await centralManager.writeCharacteristic(
      p,
      c,
      value: Uint8List.fromList(utf8.encode(filename)),
      type: GATTCharacteristicWriteType.withResponse,
    );
    _logger.logInfo('이벤트 클립 파일명 전송 완료');
  }
}
