import 'dart:async';
import 'dart:io';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:flutter/services.dart';
import '../../models/bluetooth_device.dart';
import '../../models/bluetooth_state.dart';
import '../../exceptions/bluetooth_exceptions.dart';
import '../bluetooth_platform_interface.dart';

/// Implementation of [BluetoothPlatformInterface] for Android
class AndroidBluetoothPlatform implements BluetoothPlatformInterface {
  /// 현재 스캔 중인지 여부
  bool _isScanning = false;

  /// 현재 연결된 상태인지 여부
  bool _isConnected = false;

  /// 현재 리스닝 상태인지 여부
  bool _isListening = false;

  /// 서버 소켓이 생성되었는지 여부
  bool _serverSocketCreated = false;

  /// Method channel for communicating with the native Android code
  final MethodChannel _channel =
      const MethodChannel('com.aclick.bluetooth_classic/android');

  /// Stream controller for discovered devices
  final StreamController<BluetoothDevice> _deviceFoundController =
      StreamController<BluetoothDevice>.broadcast();

  /// Stream controller for Bluetooth state changes
  final StreamController<BluetoothAdapterState> _stateChangeController =
      StreamController<BluetoothAdapterState>.broadcast();

  /// Stream controller for connection state changes
  final StreamController<BluetoothConnectionEvent>
      _bluetoothConnectionEventController =
      StreamController<BluetoothConnectionEvent>.broadcast();

  /// Stream controller for received data
  final StreamController<List<int>> _dataReceivedController =
      StreamController<List<int>>.broadcast();

  /// Stream of discovered devices
  Stream<BluetoothDevice> get deviceFoundStream =>
      _deviceFoundController.stream;

  /// BluetoothPlatformInterface 구현 - 발견된 장치 스트림
  @override
  Stream<BluetoothDevice> get discoveredDevices =>
      _deviceFoundController.stream;

  /// BluetoothPlatformInterface 구현 - 수신된 데이터 스트림
  @override
  Stream<List<int>> get receivedData => _dataReceivedController.stream;

  /// Stream of Bluetooth state changes
  @override
  Stream<BluetoothAdapterState> get adapterStateChangeStream =>
      _stateChangeController.stream;

  /// Stream of connection state changes
  @override
  Stream<BluetoothConnectionEvent> get bluetoothConnectionEventStream =>
      _bluetoothConnectionEventController.stream;

  /// Currently connected device
  BluetoothDevice? _connectedDevice;

  /// Device cache for fast lookup by address
  final Map<String, BluetoothDevice> _deviceCache = {};

  /// Constructor
  AndroidBluetoothPlatform() {
    // Set up method call handler
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle incoming method calls from platform
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDeviceFound':
        _handleDeviceFound(call.arguments);
        break;
      case 'onBluetoothStateChanged':
        _handleBluetoothStateChanged(call.arguments);
        break;
      case 'onDeviceConnected':
        _handleDeviceConnected(call.arguments);
        break;
      case 'onDeviceDisconnected':
        _handleDeviceDisconnected(call.arguments);
        break;
      case 'onConnectionFailed':
        _handleConnectionFailed(call.arguments);
        break;
      case 'onDataReceived':
        _handleDataReceived(call.arguments);
        break;
      default:
        throw MissingPluginException('Method ${call.method} not implemented');
    }
  }

  /// Handle device found event
  void _handleDeviceFound(dynamic arguments) {
    if (arguments is! Map) return;

    final device = BluetoothDevice(
      address: arguments['address'] as String,
      name: arguments['name'] as String?,
      rssi: arguments['rssi'] as int?,
      isPaired: arguments['isPaired'] as bool? ?? false,
      deviceClass: arguments['deviceClass'] as int? ?? 0,
    );

    // 생성된 디바이스 객체를 캐시에 저장
    _deviceCache[device.address] = device;

    _deviceFoundController.add(device);
  }

  /// Handle Bluetooth state changed event
  void _handleBluetoothStateChanged(dynamic arguments) {
    if (arguments is! Map) return;

    final stateStr = arguments['state'] as String?;
    BluetoothAdapterState state;

    switch (stateStr) {
      case 'enabled':
        state = BluetoothAdapterState.enabled;
        break;
      case 'disabled':
        state = BluetoothAdapterState.disabled;
        break;
      case 'turningOn':
        state = BluetoothAdapterState.turningOn;
        break;
      case 'turningOff':
        state = BluetoothAdapterState.turningOff;
        break;
      case 'unauthorized':
        state = BluetoothAdapterState.unauthorized;
        break;
      default:
        state = BluetoothAdapterState.unknown;
    }

    _stateChangeController.add(state);
  }

  /// Handle device connected event
  void _handleDeviceConnected(dynamic arguments) {
    if (arguments is! Map) return;

    final address = arguments['address'] as String?;
    final name = arguments['name'] as String?;

    if (address != null) {
      // 상태 갱신
      _isConnected = true;
      _serverSocketCreated = false;

      // 연결된 장치 객층 생성/업데이트
      _connectedDevice = BluetoothDevice(
        address: address,
        name: name ?? 'Unknown Device',
        isPaired: true,
        deviceClass: 0,
      );

      final connection = BluetoothConnection(
        getDeviceByAddress(address),
        sendDataFn: sendData,
        receiveStream: receivedData,
        disconnectFn: disconnect,
      );

      // 이벤트 알림
      _bluetoothConnectionEventController
          .add(BluetoothConnectionEvent.connect(connection));

      print("Bluetooth Device Connected: ${name ?? 'Unknown'} ($address)");
    }
  }

  /// Handle device disconnected event
  void _handleDeviceDisconnected(dynamic arguments) {
    if (arguments is! Map) return;

    final address = arguments['address'] as String?;

    if (address != null) {
      _bluetoothConnectionEventController
          .add(BluetoothConnectionEvent.disconnect(address));
      _connectedDevice = null;
    }
  }

  /// Handle connection failed event
  void _handleConnectionFailed(dynamic arguments) {
    if (arguments is! Map) return;

    final address = arguments['address'] as String?;
    final error = arguments['error'] as String?;

    if (address != null) {
      _bluetoothConnectionEventController
          .add(BluetoothConnectionEvent.fail(address, error: error));
      _connectedDevice = null;
    }
  }

  /// Handle data received event
  void _handleDataReceived(dynamic arguments) {
    if (arguments is! Map) return;

    final data = arguments['data'] as List<dynamic>?;

    if (data != null) {
      final bytes = data.map((e) => e as int).toList();
      _dataReceivedController.add(bytes);
    }
  }

  @override
  Future<bool> initializeAdapter() async {
    try {
      final result = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('initializeAdapter');
      final isAvailable = result?['isAvailable'] as bool? ?? false;
      final isEnabled = result?['isEnabled'] as bool? ?? false;

      if (!isAvailable) {
        throw BluetoothUnavailableException(
            'Bluetooth is not available on this device');
      }

      return isEnabled;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to initialize Bluetooth adapter: ${e.message}',
        e.code, // positional parameter로 변경
      );
    }
  }

  @override
  Future<bool> requestEnable() async {
    try {
      final enabled =
          await _channel.invokeMethod<bool>('requestEnable') ?? false;
      return enabled;
    } on PlatformException catch (e) {
      if (e.code == 'ACTIVITY_UNAVAILABLE') {
        throw BluetoothException(
          'Cannot request Bluetooth enable: Activity unavailable',
          e.code, // positional parameter
        );
      }
      throw BluetoothException(
        'Failed to request Bluetooth enable: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<bool> startScan({bool onlyPaired = false}) async {
    try {
      final success = await _channel.invokeMethod<bool>(
            'startScan',
            {'onlyPaired': onlyPaired},
          ) ??
          false;

      return success;
    } on PlatformException catch (e) {
      if (e.code == 'ACTIVITY_UNAVAILABLE') {
        throw BluetoothException(
          'Cannot start scan: Activity unavailable',
          e.code, // positional parameter
        );
      }
      throw BluetoothException(
        'Failed to start scan: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<bool> stopScan() async {
    try {
      final success = await _channel.invokeMethod<bool>('stopScan') ?? false;
      return success;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to stop scan: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      final List<dynamic>? devicesList =
          await _channel.invokeMethod('getPairedDevices');

      if (devicesList == null || devicesList.isEmpty) {
        return [];
      }

      final List<BluetoothDevice> devices = devicesList.map((device) {
        final bluetoothDevice = BluetoothDevice(
          address: device['address'] as String,
          name: device['name'] as String?,
          isPaired: true,
          deviceClass: device['deviceClass'] as int? ?? 0,
          rssi: null, // Paired devices don't have RSSI info from system API
        );

        // 생성된 디바이스 객체를 캐시에 저장
        _deviceCache[bluetoothDevice.address] = bluetoothDevice;

        return bluetoothDevice;
      }).toList();

      return devices;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to get paired devices: ${e.message}',
        e.code,
      );
    }
  }

  /// 주소로 장치 검색
  ///
  /// 캐시에서 검색하고, 없으면 페어링된 기기 목록을 조회해 검색
  @override
  BluetoothDevice getDeviceByAddress(String address) {
    // 이미 캐시에 있는 것을 확인
    final cached = _deviceCache[address];
    if (cached != null) return cached;

    // 현재 연결된 장치인지 확인
    final connected = _connectedDevice;
    if (connected != null && connected.address == address) {
      return connected;
    }

    // 캐시에 없는 경우, 가장 좋은 방법은 페어링된 기기 목록을 가져와서 검색하는 것이지만 비동기이기 때문에
    // 이 메서드를 통해 하기는 어려움
    // 대신, 주소만을 이용해 임시 객체 생성
    print('주소로 임시 BluetoothDevice 객체 생성: $address');
    final device = BluetoothDevice(
      address: address,
      name: 'Unknown Device',
      // 이름은 나중에 업데이트될 수 있음
      isPaired: true,
      // 연결되려면 페어링되어 있어야 하는 것으로 가정
      deviceClass: 0,
      rssi: null,
    );

    // 캐시에 저장
    _deviceCache[address] = device;

    return device;
  }

  @override
  Future<BluetoothConnection?> connect(BluetoothDevice device) async {
    try {
      final success = await _channel.invokeMethod<bool>(
            'connect',
            {'address': device.address},
          ) ??
          false;

      if (success) {
        _connectedDevice = device;

        return BluetoothConnection(
          device,
          sendDataFn: sendData,
          receiveStream: receivedData,
          disconnectFn: disconnect,
        );
      }

      return null;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to connect to device: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      final success = await _channel.invokeMethod<bool>('disconnect') ?? false;

      if (success) {
        _connectedDevice = null;
      }

      return success;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to disconnect: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<bool> sendData(List<int> data) async {
    try {
      if (_connectedDevice == null) {
        throw DeviceNotConnectedException('No device connected');
      }

      final success = await _channel.invokeMethod<bool>(
            'sendData',
            {'data': data},
          ) ??
          false;

      return success;
    } on PlatformException catch (e) {
      throw BluetoothTransmissionException('Failed to send data: ${e.message}');
    }
  }

  /// Check if Bluetooth is enabled
  Future<bool> isEnabled() async {
    try {
      final enabled = await _channel.invokeMethod<bool>('isEnabled') ?? false;
      return enabled;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to check if Bluetooth is enabled: ${e.message}',
        e.code, // positional parameter
      );
    }
  }

  @override
  Future<bool> isScanning() async {
    return _isScanning;
  }

  @override
  Future<bool> isConnected() async {
    try {
      final bool result = await _channel.invokeMethod('isConnected');
      _isConnected = result;
      return result;
    } on PlatformException catch (e) {
      throw BluetoothException(
          'Failed to check connection state: ${e.message}', e.code);
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      // Android 12+ (API 31+) requires BLUETOOTH_CONNECT and BLUETOOTH_SCAN
      if (Platform.isAndroid) {
        final Map<dynamic, dynamic>? androidInfo =
            await _channel.invokeMethod('getAndroidInfo');
        final int sdkInt = androidInfo?['sdkInt'] ?? 0;

        if (sdkInt >= 31) {
          // Android 12+ requires BLUETOOTH_CONNECT and BLUETOOTH_SCAN
          final bool result = await _channel.invokeMethod(
              'requestPermissions', {'permissionType': 'android12'});
          return result;
        } else if (sdkInt >= 23) {
          // Android 6.0+ requires LOCATION permission for discovery
          final bool result = await _channel.invokeMethod(
              'requestPermissions', {'permissionType': 'android6'});
          return result;
        } else {
          // Earlier Android versions don't need runtime permissions for Bluetooth
          return true;
        }
      } else {
        // Not Android platform
        return true;
      }
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to request permissions: ${e.message}',
        e.code,
      );
    }
  }

  @override
  Future<bool> listenUsingRfcomm({
    String? name,
    String? uuid,
    bool secured = true,
  }) async {
    try {
      if (_serverSocketCreated) {
        // 이미 서버 소켓이 생성되어 있는 경우
        return true;
      }

      final bool success = await _channel.invokeMethod('listenUsingRfcomm', {
        'name': name,
        'uuid': uuid,
        'secured': secured,
      });

      if (success) {
        _serverSocketCreated = true;
        _isListening = true;
      }

      return success;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to create server socket: ${e.message}',
        e.code,
      );
    }
  }

  // acceptConnection 메서드 완전히 삭제됨 (2025-05-17)
  // 이 쓸모없는 코드는 한번도 제대로 동작한 적이 없었음
  // 이제 연결은 ACTION_ACL_CONNECTED 및 ACTION_ACL_DISCONNECTED 브로드캐스트를 통해 자동으로 처리됨

  @override
  Future<bool> setCustomUuid(String uuid) async {
    try {
      final bool success = await _channel.invokeMethod('setCustomUuid', {
        'uuid': uuid,
      });

      return success;
    } on PlatformException catch (e) {
      throw BluetoothException(
        'Failed to set custom UUID: ${e.message}',
        e.code,
      );
    }
  }

  /// 자원 해제
  void dispose() {
    _dataReceivedController.close();
    _deviceFoundController.close();
    _stateChangeController.close();
    _bluetoothConnectionEventController.close();
  }

  @override
  void addDiscoveredDevice(BluetoothDevice device) {
    // TODO: implement addDiscoveredDevice
    throw UnimplementedError();
  }
}
