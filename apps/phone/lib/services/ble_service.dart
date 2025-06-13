import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone/models/event_record.dart';
import 'package:phone/models/hotspot_info.dart';
import 'package:phone/services/report_repository.dart';
import 'package:phone/viewmodels/log_view_model.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:core/core.dart';

final bleServiceProvider = NotifierProvider<BleService, void>(
      () {
    return BleService();
  },
);

class BleService extends Notifier<void> {
  /// 라이브러리
  // LogViewModel get _logger => ref.read(logViewModelProvider.notifier);
  void _log(String message) => FlutterForegroundTask.sendDataToMain(message);
  final peripheralManager = PeripheralManager();

  /// 객체 관리
  Central? _central;

  /// GATT 관리


  /// 상태 관련
  bool _initialized = false;
  bool _isAdvertising = false;
  bool _isConnected = false;
  ConnectionState _connectionState = ConnectionState.disconnected;
  BluetoothLowEnergyState _state = BluetoothLowEnergyState.unknown;
  bool get isEnabled => _initialized && _state == BluetoothLowEnergyState.poweredOn;

  /// 구독 관리
  late final StreamSubscription _stateChangedSubscription;
  late final StreamSubscription _connectionStateChangedSubscription;
  late final StreamSubscription _characteristicReadRequestedSubscription;
  late final StreamSubscription _characteristicWriteRequestedSubscription;
  late final StreamSubscription _characteristicNotifyStateChangedSubscription;

  /// 외부로 스트림
  final StreamController<String> _eventClipStreamController = StreamController<String>.broadcast();
  Stream<String> get newEventClipStream => _eventClipStreamController.stream.asBroadcastStream();
  final StreamController<HotspotInfo> _wifiCredentialStreamController = StreamController<HotspotInfo>.broadcast();
  Stream<HotspotInfo> get wifiCredentialStream => _wifiCredentialStreamController.stream;

  @override
  void build() {
    ref.keepAlive();
    initialize();
    return;
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;

    /// 기본 상태 구독
    _stateChangedSubscription = peripheralManager.stateChanged.listen((
      eventArgs,
    ) async {
      _state = eventArgs.state;
      print('stateChanged: ${eventArgs.state}');
      if (eventArgs.state == BluetoothLowEnergyState.unauthorized &&
          Platform.isAndroid) {
        await peripheralManager.authorize();
      }
      if (eventArgs.state == BluetoothLowEnergyState.poweredOn) startAdvertising();
    });

    /// 연결 상태 구독
    _connectionStateChangedSubscription = peripheralManager.connectionStateChanged.listen((
      CentralConnectionStateChangedEventArgs eventArgs,
    ) async {
      final c = eventArgs.central;
      _central = c;
      switch (eventArgs.state) {
        case ConnectionState.connected:
          _log('Connected to ${c.uuid}');
          _isConnected = true;
          stopAdvertising();
          break;
        case ConnectionState.disconnected:
          _log('Disconnected to ${c.uuid}');
          _isConnected = false;
          startAdvertising();
          break;
      }
      _connectionState = eventArgs.state;
    });

    /// 읽기요청 구독
    _characteristicReadRequestedSubscription = peripheralManager
        .characteristicReadRequested
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
          final elements = List.generate(5, (i) => i % 256);
          final value = Uint8List.fromList(elements);
          final trimmedValue = value.sublist(offset);
          _log(
            'Read Request: ${trimmedValue} @${characteristic.uuid}:${offset}',
          );
          await peripheralManager.respondReadRequestWithValue(
            request,
            value: trimmedValue,
          );
        });

    /// 쓰기요청 구독
    _characteristicWriteRequestedSubscription = peripheralManager
        .characteristicWriteRequested
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final request = eventArgs.request;
          final offset = request.offset;
          final value = request.value;
          _log(
            'Write Request: ${value} @${characteristic.uuid}:${offset}',
          );
          await peripheralManager.respondWriteRequest(request);
          if(characteristic.uuid == UUID.fromString(BLE_GATT_WIFI_UUID)){
            _handleWifiCredential(value);
          }
          if(characteristic.uuid == UUID.fromString(BLE_GATT_PING_UUID)){
            _handlePing(value);
          }
          if(characteristic.uuid == UUID.fromString(BLE_GATT_NEW_EVENT_CLIP_UUID)){
            _handleNewEventClip(value);
          }
        });

    /// Notify 구독
    _characteristicNotifyStateChangedSubscription = peripheralManager
        .characteristicNotifyStateChanged
        .listen((eventArgs) async {
          final central = eventArgs.central;
          final characteristic = eventArgs.characteristic;
          final state = eventArgs.state;

          // Write someting to the central when notify started.
          if (state) {
            final maximumNotifyLength = await peripheralManager
                .getMaximumNotifyLength(central);
            final elements = List.generate(5, (i) => i % 256);
            final value = Uint8List.fromList(elements);
            _log('Notify Start: ${value} @${characteristic.uuid}');
            pingGatt = characteristic;
            // await peripheralManager.notifyCharacteristic(
            //   central,
            //   characteristic,
            //   value: value,
            // );
          }
        });

    return;
  }

  void dispose() {
    _stateChangedSubscription.cancel();
    _connectionStateChangedSubscription.cancel();
    _characteristicReadRequestedSubscription.cancel();
    _characteristicWriteRequestedSubscription.cancel();
    _characteristicNotifyStateChangedSubscription.cancel();
  }

  Future<void> stopAdvertising() async {
    if(!isEnabled) return;
    _isAdvertising = false;
    await peripheralManager.stopAdvertising();
  }

  GATTService get _gattService =>
      GATTService(
        uuid: UUID.fromString(BLE_SERVICE_UUID),
        isPrimary: true,
        includedServices: [],
        characteristics: [wifiCredentialGatt(), pingGatt, newEventClipGatt()],
      );

  Future<void> startAdvertising() async {
    if(!isEnabled) return;
    if (_isAdvertising) return;
    _isAdvertising = true;
    await peripheralManager.removeAllServices();
    await peripheralManager.addService(_gattService);
    final advertisement = Advertisement(
      name: 'Aclick',
      serviceUUIDs: [UUID.fromString(BLE_SERVICE_UUID)],
      manufacturerSpecificData:
          Platform.isIOS || Platform.isMacOS
              ? []
              : [
                ManufacturerSpecificData(
                  id: 0x2e19,
                  data: Uint8List.fromList([0x01, 0x02, 0x03]),
                ),
              ],
    );
    await peripheralManager.stopAdvertising();
    await peripheralManager.startAdvertising(advertisement);
  }

  GATTCharacteristic wifiCredentialGatt() {
    return GATTCharacteristic.mutable(
      uuid: UUID.fromString(BLE_GATT_WIFI_UUID),
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
        GATTCharacteristicProperty.indicate,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [],
    );
  }

  GATTCharacteristic newEventClipGatt() {
    return GATTCharacteristic.mutable(
      uuid: UUID.fromString(BLE_GATT_NEW_EVENT_CLIP_UUID),
      properties: [
        GATTCharacteristicProperty.read,
        GATTCharacteristicProperty.write,
        GATTCharacteristicProperty.writeWithoutResponse,
        GATTCharacteristicProperty.notify,
        GATTCharacteristicProperty.indicate,
      ],
      permissions: [
        GATTCharacteristicPermission.read,
        GATTCharacteristicPermission.write,
      ],
      descriptors: [],
    );
  }


  Future<void> sendNotification() async {
    if(!_isConnected) return;
    if(_central == null) return;

    await peripheralManager.notifyCharacteristic(
      _central!,
      pingGatt, // pingGatt(),
      value: Uint8List.fromList([0x05, 0x02, 0x03]),
    );
  }

  Future<void> _handlePing(Uint8List data) async {

  }
  Future<void> _handleWifiCredential(Uint8List data) async {
    final jsonString = utf8.decode(data);
    _log(jsonString);
    final Map<String, dynamic> map = jsonDecode(jsonString);
    _wifiCredentialStreamController.add(HotspotInfo.fromJson(map));
  }

  void _handleNewEventClip(Uint8List data) {
    // final filename = utf8.decode(data);
    // _log('New Event Clip: ${filename}');
    // _eventClipStreamController.add(filename);
    ReportRepository.instance.saveEventRecord(
        EventRecord.fromJson(jsonDecode(utf8.decode(data))));
  }

}

extension PingGatt on BleService {
  GATTCharacteristic? _pingGatt;

  GATTCharacteristic get pingGatt =>
      _pingGatt ?? GATTCharacteristic.mutable(
        uuid: UUID.fromString(BLE_GATT_PING_UUID),
        properties: [
          GATTCharacteristicProperty.read,
          GATTCharacteristicProperty.write,
          GATTCharacteristicProperty.writeWithoutResponse,
          GATTCharacteristicProperty.notify,
          GATTCharacteristicProperty.indicate,
        ],
        permissions: [
          GATTCharacteristicPermission.read,
          GATTCharacteristicPermission.write,
        ],
        descriptors: [],
      );

  set pingGatt(GATTCharacteristic newPingGatt) {
    if (UUID.fromString(BLE_GATT_PING_UUID) == newPingGatt.uuid) {
      _pingGatt = newPingGatt;
    }
  }
}