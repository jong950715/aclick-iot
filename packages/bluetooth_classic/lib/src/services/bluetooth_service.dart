import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:rxdart/rxdart.dart';

import '../exceptions/bluetooth_exceptions.dart';
import '../models/bluetooth_device.dart';
import '../models/bluetooth_state.dart';
import '../models/connection_config.dart';
import '../models/connection_state.dart';
import '../platform/bluetooth_platform_interface.dart';
import '../platform/android/android_bluetooth_platform.dart';
import 'bluetooth_connection.dart';
// import '../platform/ios/ios_bluetooth_platform.dart';  // 미래 구현용

/// Main service class for Bluetooth Classic operations
///
/// [BluetoothService] is the primary entry point for working with Bluetooth Classic
/// functionality in Flutter applications. It provides methods for device discovery,
/// connection management, and adapter state monitoring.
///
/// Usage example:
/// ```dart
/// final bluetoothService = BluetoothService();
///
/// // Check if Bluetooth is available and enabled
/// if (await bluetoothService.isAvailable() && await bluetoothService.isEnabled()) {
///   // Start device discovery
///   await bluetoothService.startDiscovery();
///
///   // Listen for discovered devices
///   bluetoothService.discoveredDevices.listen((device) {
///     print('Found device: ${device.name}');
///   });
/// }
/// ```
///
/// The service automatically handles permissions and platform-specific implementations.
class BluetoothService {
  /// The platform-specific implementation
  final BluetoothPlatformInterface _platform;

  /// Stream controller for device connection established events
  final StreamController<BluetoothDevice> _connectionEstablishedController =
      StreamController<BluetoothDevice>.broadcast();

  /// Singleton instance
  static BluetoothService? _instance;

  /// Factory constructor that returns a singleton instance
  factory BluetoothService() {
    _instance ??= BluetoothService._internal();
    return _instance!;
  }

  /// Internal constructor that initializes the platform-specific implementation
  BluetoothService._internal() : _platform = _createPlatformImplementation() {
    // Bluetooth 상태 변경 이벤트 처리
    _platform.adapterStateChangeStream.listen((state) {
      _adapterState = state;
      _adapterStateController.add(state);
    });

    _platform.bluetoothConnectionEventStream
        .listen((BluetoothConnectionEvent event) async {
      return await handleBluetoothConnectionEvent(event);
    });
  }

  /// Creates the appropriate platform implementation based on the current platform
  static BluetoothPlatformInterface _createPlatformImplementation() {
    if (Platform.isAndroid) {
      return AndroidBluetoothPlatform();
    } else if (Platform.isIOS) {
      // iOS implementation will be added in the future
      throw UnsupportedOperationException(
          'iOS implementation is not available yet');
    } else {
      throw UnsupportedOperationException(
          'Bluetooth Classic is not supported on this platform');
    }
  }

  /// Stream controller for Bluetooth state changes
  final StreamController<BluetoothAdapterState> _adapterStateController =
      StreamController<BluetoothAdapterState>.broadcast();

  /// Stream controller for connection state changes
  final StreamController<BluetoothConnectionState>
      _bluetoothConnectionStateController =
      StreamController<BluetoothConnectionState>.broadcast();

  final _connSubject = BehaviorSubject<BluetoothConnection?>.seeded(null);
  BehaviorSubject<BluetoothConnection?> get connectionStream => _connSubject;
  /// 수신 데이터 송출 스트림
  Stream<List<int>> get dataStream => _connSubject.stream
      .switchMap((conn) => conn?.dataStream ?? Stream.empty());
  // 연결이 바뀔 때마다 subject 에 add
  set _currentConnection(BluetoothConnection? conn) {
    _connSubject.add(conn);
  }
  BluetoothConnection? get _currentConnection => _connSubject.value;

  /// The latest Bluetooth adapter state
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  /// Stream of discovered Bluetooth devices
  ///
  /// Listen to this stream to receive devices as they are discovered during a scan.
  Stream<BluetoothDevice> get discoveredDevices => _platform.discoveredDevices;

  /// Stream of Bluetooth state changes
  Stream<BluetoothAdapterState> get adapterStateChanges =>
      _adapterStateController.stream;

  /// Stream of connection state changes
  Stream<BluetoothConnectionState> get connectionStateChanges =>
      _bluetoothConnectionStateController.stream;

  /// Get current Bluetooth adapter state
  BluetoothAdapterState get adapterState => _adapterState;

  /// Get current connection instance
  BluetoothConnection? get currentConnection => _currentConnection;

  Future<void> handleBluetoothConnectionEvent(
      BluetoothConnectionEvent event) async {
    switch (event) {
      case BluetoothConnectedEvent():
        _bluetoothConnectionStateController
            .add(BluetoothConnectionState.connected);
        return await _handleConnected(event);
      case BluetoothDisconnectedEvent():
        _bluetoothConnectionStateController
            .add(BluetoothConnectionState.disconnected);
        return await _handleDisconnected(event);
      case BluetoothConnectionFailedEvent():
        _bluetoothConnectionStateController
            .add(BluetoothConnectionState.failed);
        return await _handleFailed(event);
    }
  }

  /// 텍스트로 디코딩된 데이터 스트림 가져오기
  /// 연결이 없으면 null 반환
  /// @param encoding 사용할 인코딩 (기본값: UTF-8)
  Stream<String>? getTextStream({Encoding encoding = utf8}) {
    return dataStream
        ?.transform(StreamTransformer.fromHandlers(handleData: (data, sink) {
      try {
        final text = encoding.decode(data);
        sink.add(text);
      } catch (e) {
        // 디코딩 오류는 무시하고 계속 진행
      }
    }));
  }

  /// 텍스트 전송 메서드 - 편의 기능
  Future<bool> sendText(String text, {Encoding encoding = utf8}) async {
    return sendData(encoding.encode(text));
  }

  /// Initializes the Bluetooth adapter
  ///
  /// This must be called before using any other Bluetooth functionality.
  /// Returns true if Bluetooth is available and enabled.
  /// Throws a [BluetoothUnavailableException] if Bluetooth is not available on the device.
  Future<bool> initializeAdapter() async {
    try {
      final isEnabled = await _platform.initializeAdapter();

      // 초기 상태 설정 및 스트림에 추가
      _adapterState = isEnabled
          ? BluetoothAdapterState.enabled
          : BluetoothAdapterState.disabled;
      _adapterStateController.add(_adapterState);

      return isEnabled;
    } catch (e) {
      // 오류 발생 시 상태 업데이트
      _adapterState = BluetoothAdapterState.unavailable;
      _adapterStateController.add(_adapterState);
      throw BluetoothUnavailableException(
          'Failed to initialize Bluetooth adapter: $e');
    }
  }

  /// Requests the user to enable Bluetooth if it is not already enabled
  ///
  /// This will display a system dialog asking the user to enable Bluetooth.
  /// Returns true if Bluetooth is enabled after this call.
  Future<bool> requestEnable() async {
    try {
      final isEnabled = await _platform.requestEnable();

      // 상태 업데이트 및 스트림에 추가
      _adapterState = isEnabled
          ? BluetoothAdapterState.enabled
          : BluetoothAdapterState.disabled;
      _adapterStateController.add(_adapterState);

      return isEnabled;
    } catch (e) {
      throw BluetoothException('Failed to enable Bluetooth: $e');
    }
  }

  /// Starts scanning for nearby Bluetooth devices
  ///
  /// Discovered devices will be emitted on the [discoveredDevices] stream.
  /// Set [onlyPaired] to true to discover only paired devices.
  /// Returns true if the scan was started successfully.
  Future<bool> startScan({bool onlyPaired = false}) async {
    try {
      return await _platform.startScan(onlyPaired: onlyPaired);
    } catch (e) {
      throw BluetoothDiscoveryException('Failed to start device discovery: $e');
    }
  }

  /// Stops an ongoing Bluetooth device scan
  ///
  /// Returns true if the scan was stopped successfully.
  Future<bool> stopScan() async {
    try {
      return await _platform.stopScan();
    } catch (e) {
      throw BluetoothException('Failed to stop device discovery: $e');
    }
  }

  /// Gets a list of Bluetooth devices that are paired with this device
  ///
  /// Returns a list of [BluetoothDevice] objects representing paired devices.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _platform.getPairedDevices();
    } catch (e) {
      throw BluetoothException('Failed to get paired devices: $e');
    }
  }

  Future<void> _handleFailed(BluetoothConnectionFailedEvent event) async {
    if (_currentConnection != null) {
      _currentConnection!.setDisconnected(attemptReconnect: false);
    }
    // TODO log 남기기 event에 error 들어 있음. 근데 사실 아직 이 event를 emit하는 루트가 없음.
  }

  Future<void> _handleDisconnected(BluetoothDisconnectedEvent event) async {
    await disconnect();
  }

  Future<void> _handleConnected(BluetoothConnectedEvent event) async {
    final connection = event.connection;

    if (_currentConnection == null ||
        _currentConnection!.device.address != connection.device.address) {
      // 주소로 장치 객체 조회
      print(
          'Creating connection object for detected native connection: ${connection.device.address}');

      // 네이티브에서 이미 연결된 소켓을 사용하는 새 연결 객체 생성
      _currentConnection = connection;
      _currentConnection!.setConnected(); // 명시적으로 연결 상태 설정
      // 연결 이벤트 발행
      _connectionEstablishedController.add(connection.device);
    } else {
      // 기존 연결 있으면 업데이트
      _currentConnection!.setConnected();
      print('Updated existing connection to connected state');
    }

    // 디버그 로깅
    print('Device connected: ${connection.device.address}');
  }

  /// Establishes a connection to a Bluetooth device
  ///
  /// The [device] parameter specifies the device to connect to.
  /// The optional [config] parameter allows configuring connection properties.
  /// Returns a [BluetoothConnection] instance that can be used to communicate with the device.
  /// Throws [BluetoothConnectionException] if connection fails.
  Future<BluetoothConnection> connect(
    BluetoothDevice device, {
    ConnectionConfig config =
        const ConnectionConfig(), // TODO config가 전혀 활용되고 있지 않음.
  }) async {
    try {
      // 기존 연결이 있으면 먼저 연결 해제
      if (_currentConnection != null) {
        await disconnect();
      }

      // 연결 시도
      final BluetoothConnection? connection = await _platform.connect(device);

      if (connection != null) {
        _currentConnection = connection;
        return connection;
      } else {
        throw BluetoothConnectionException(
            'Failed to connect to ${device.name ?? device.address}');
      }
    } on BluetoothException catch (e) {
      throw e;
    } catch (e) {
      throw BluetoothConnectionException('Failed to connect to device: $e');
    }
  }

  /// Disconnects from the currently connected Bluetooth device
  ///
  /// Returns true if disconnection was successful.
  Future<bool> disconnect() async {
    try {
      // 플랫폼 연결 해제
      final result = await _platform.disconnect();

      // 현재 연결이 있으면 리소스 정리
      if (result && _currentConnection != null) {
        _currentConnection!.dispose();
        _currentConnection = null;
      }

      return result;
    } on BluetoothException catch (e) {
      throw e;
    } catch (e) {
      throw BluetoothException('Failed to disconnect: $e');
    }
  }

  /// Sends data to the connected Bluetooth device using the current connection
  ///
  /// The [data] parameter contains the bytes to send.
  /// Returns true if the data was sent successfully.
  /// Throws [DeviceNotConnectedException] if no device is connected.
  Future<bool> sendData(List<int> data) async {
    try {
      // 연결된 장치가 없으면 예외 발생
      if (_currentConnection == null) {
        throw DeviceNotConnectedException('No device connected');
      }

      // 현재 연결을 사용해 데이터 전송
      return await _currentConnection!.sendData(data);
    } on BluetoothException catch (e) {
      throw e;
    } catch (e) {
      if (e is DeviceNotConnectedException) rethrow;
      throw BluetoothTransmissionException('Failed to send data: $e');
    }
  }

  /// Request necessary Bluetooth permissions based on Android SDK version
  ///
  /// On Android 12+ (API 31+), this requests BLUETOOTH_CONNECT and BLUETOOTH_SCAN permissions.
  /// On Android 6.0+ (API 23+), this requests LOCATION permissions required for discovery.
  /// Returns true if all required permissions are granted.
  Future<bool> requestPermissions() async {
    try {
      return await _platform.requestPermissions();
    } catch (e) {
      throw BluetoothException('Failed to request Bluetooth permissions: $e');
    }
  }

  /// Create a listening RFCOMM BluetoothServerSocket with Service Discovery Protocol
  ///
  /// The [name] parameter specifies the SDP service name.
  /// The [uuid] parameter specifies the UUID for the service.
  /// Set [secured] to true to create a secure socket (requires pairing).
  /// Returns true if server socket was created successfully.
  Future<bool> listenUsingRfcomm({
    String? name,
    String? uuid,
    bool secured = true,
  }) async {
    try {
      return await _platform.listenUsingRfcomm(
        name: name,
        uuid: uuid,
        secured: secured,
      );
    } catch (e) {
      throw BluetoothException('Failed to create Bluetooth server socket: $e');
    }
  }

  // NOTE: acceptConnection 메서드가 이 위치에 존재했지만 완전히 삭제되었습니다. (2025-05-17)
  // 이 메서드는 실제로 한번도 제대로 동작한 적이 없었으며, 기존의 메서드 호출 코드는 삭제하거나 수정해야 합니다.
  // 이제 연결 객체는 ACTION_ACL_CONNECTED 및 ACTION_ACL_DISCONNECTED 이벤트를 통해
  // 자동으로 처리됩니다.

  /// Checks if Bluetooth is currently enabled
  ///
  /// Returns true if Bluetooth is enabled.
  Future<bool> isEnabled() async {
    try {
      return await _platform.isEnabled();
    } catch (e) {
      throw BluetoothException('Failed to check Bluetooth state: $e');
    }
  }

  /// Checks if a Bluetooth scan is currently in progress
  ///
  /// Returns true if a scan is in progress.
  Future<bool> isScanning() async {
    try {
      return await _platform.isScanning();
    } catch (e) {
      throw BluetoothException('Failed to check scan state: $e');
    }
  }

  /// Checks if connected to a Bluetooth device
  ///
  /// Returns true if currently connected to a device.
  Future<bool> isConnected() async {
    try {
      return await _platform.isConnected();
    } catch (e) {
      throw BluetoothException('Failed to check connection state: $e');
    }
  }

  /// Stream that emits devices as they are connected via native events
  Stream<BluetoothDevice> get connectionEstablished =>
      _connectionEstablishedController.stream;

  /// Set a custom UUID for Bluetooth connections
  ///
  /// The [uuid] parameter specifies the UUID string to use for all Bluetooth communications.
  /// This is useful for custom protocols or to ensure compatibility with specific devices.
  /// The UUID must be in the format "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx".
  ///
  /// Returns true if the UUID was set successfully.
  Future<bool> setCustomUuid(String uuid) async {
    try {
      return await _platform.setCustomUuid(uuid);
    } catch (e) {
      throw BluetoothException('Failed to set custom UUID: $e');
    }
  }

  /// Disposes of resources used by this service
  ///
  /// This should be called when the service is no longer needed.
  void dispose() {
    // 현재 연결 정리
    _currentConnection?.dispose();
    _currentConnection = null;

    // 스트림 컨트롤러 정리
    _adapterStateController.close();
    _bluetoothConnectionStateController.close();
    _connectionEstablishedController.close();

    // 플랫폼 자원 정리
    if (_platform is AndroidBluetoothPlatform) {
      (_platform as AndroidBluetoothPlatform).dispose();
    } else {
      _platform.dispose();
    }

    _instance = null;
  }
}
