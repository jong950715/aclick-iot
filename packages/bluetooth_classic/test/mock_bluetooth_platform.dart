// import 'package:bluetooth_classic/src/models/bluetooth_device.dart';
// import 'package:bluetooth_classic/src/models/connection_config.dart';
// import 'package:bluetooth_classic/src/platform/bluetooth_platform_interface.dart';
// import 'package:bluetooth_classic/src/exceptions/bluetooth_exceptions.dart';
// import 'package:bluetooth_classic/src/services/bluetooth_connection.dart';
//
// /// Mock implementation of the Bluetooth platform interface for testing
// class MockBluetoothPlatform implements BluetoothPlatformInterface {
//   bool isAvailableResult = true;
//   bool isEnabledResult = true;
//   List<BluetoothDevice> pairedDevicesResult = [];
//   bool shouldThrowDeviceNotFound = false;
//   bool startDiscoveryCalled = false;
//   bool stopDiscoveryCalled = false;
//   late BluetoothDevice lastConnectDevice;
//   late ConnectionConfig lastConnectConfig;
//
//   @override
//   Stream<BluetoothAdapterState> get stateChanges =>
//       Stream.value(BluetoothAdapterState.on);
//
//   @override
//   Stream<BluetoothDevice> get discoveredDevices =>
//       Stream.fromIterable(pairedDevicesResult);
//
//   @override
//   Future<bool> isAvailable() async => isAvailableResult;
//
//   @override
//   Future<bool> isEnabled() async => isEnabledResult;
//
//   @override
//   Future<List<BluetoothDevice>> getPairedDevices() async =>
//       pairedDevicesResult;
//
//   @override
//   Future<bool> startDiscovery() async {
//     startDiscoveryCalled = true;
//     return true;
//   }
//
//   @override
//   Future<bool> stopDiscovery() async {
//     stopDiscoveryCalled = true;
//     return true;
//   }
//
//   @override
//   Future<bool> requestEnable() async => true;
//
//   @override
//   Future<bool> isDiscovering() async => false;
//
//   @override
//   Future<BluetoothConnection> connect(
//     BluetoothDevice device,
//     ConnectionConfig config
//   ) async {
//     if (shouldThrowDeviceNotFound) {
//       throw DeviceNotFoundException('Device not found: ${device.address}');
//     }
//
//     lastConnectDevice = device;
//     lastConnectConfig = config;
//
//     // Create a mock connection
//     return BluetoothConnection(
//       device,
//       config: config,
//       sendFunction: (data) async => true,
//       receiveStream: Stream.empty(),
//     );
//   }
//
//   @override
//   Future<bool> requestDisable() async => true;
//
//   @override
//   void dispose() {
//     // No-op for mock
//   }
// }
