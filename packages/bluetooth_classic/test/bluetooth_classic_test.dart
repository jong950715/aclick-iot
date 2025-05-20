// import 'package:flutter_test/flutter_test.dart';
// import 'package:bluetooth_classic/bluetooth_classic.dart';
// import 'package:bluetooth_classic/src/models/bluetooth_device.dart';
// import 'package:bluetooth_classic/src/models/connection_config.dart';
// import 'package:bluetooth_classic/src/exceptions/bluetooth_exceptions.dart';
//
// import 'mock_bluetooth_platform.dart';
//
// void main() {
//   group('BluetoothService Tests', () {
//     late BluetoothService service;
//     late MockBluetoothPlatform mockPlatform;
//
//     setUp(() {
//       mockPlatform = MockBluetoothPlatform();
//       service = BluetoothService.withPlatform(mockPlatform);
//     });
//
//     test('isAvailable returns correct value from platform', () async {
//       mockPlatform.isAvailableResult = true;
//       expect(await service.isAvailable(), true);
//
//       mockPlatform.isAvailableResult = false;
//       expect(await service.isAvailable(), false);
//     });
//
//     test('isEnabled returns correct value from platform', () async {
//       mockPlatform.isEnabledResult = true;
//       expect(await service.isEnabled(), true);
//
//       mockPlatform.isEnabledResult = false;
//       expect(await service.isEnabled(), false);
//     });
//
//     test('getPairedDevices returns devices from platform', () async {
//       final testDevices = [
//         BluetoothDevice(
//           name: 'Test Device 1',
//           address: '00:11:22:33:44:55',
//           type: DeviceType.classic,
//           bondState: BondState.bonded,
//           rssi: -70,
//         ),
//         BluetoothDevice(
//           name: 'Test Device 2',
//           address: '55:44:33:22:11:00',
//           type: DeviceType.classic,
//           bondState: BondState.bonded,
//           rssi: -80,
//         ),
//       ];
//
//       mockPlatform.pairedDevicesResult = testDevices;
//       final result = await service.getPairedDevices();
//
//       expect(result, hasLength(2));
//       expect(result[0].name, 'Test Device 1');
//       expect(result[1].address, '55:44:33:22:11:00');
//     });
//
//     test('connect throws DeviceNotFoundException when device not found', () async {
//       mockPlatform.shouldThrowDeviceNotFound = true;
//
//       final device = BluetoothDevice(
//         name: 'Non-existent Device',
//         address: '00:00:00:00:00:00',
//         type: DeviceType.classic,
//       );
//
//       expect(
//         () => service.connect(device),
//         throwsA(isA<DeviceNotFoundException>())
//       );
//     });
//
//     test('connect passes config to platform correctly', () async {
//       final device = BluetoothDevice(
//         name: 'Test Device',
//         address: '00:11:22:33:44:55',
//         type: DeviceType.classic,
//       );
//
//       final config = ConnectionConfig(
//         autoReconnect: true,
//         connectionTimeout: 20000,
//         maxReconnectAttempts: 5,
//       );
//
//       await service.connect(device, config: config);
//
//       expect(mockPlatform.lastConnectConfig, config);
//       expect(mockPlatform.lastConnectDevice.address, device.address);
//     });
//
//     test('startDiscovery and stopDiscovery call platform methods', () async {
//       await service.startDiscovery();
//       expect(mockPlatform.startDiscoveryCalled, true);
//
//       await service.stopDiscovery();
//       expect(mockPlatform.stopDiscoveryCalled, true);
//     });
//   });
//
//   group('BluetoothConnection Model Tests', () {
//     test('ConnectionConfig initializes with correct defaults', () {
//       final defaultConfig = ConnectionConfig();
//
//       expect(defaultConfig.autoReconnect, false);
//       expect(defaultConfig.connectionTimeout, 10000);
//       expect(defaultConfig.maxReconnectAttempts, 3);
//       expect(defaultConfig.reconnectDelayMs, 2000);
//     });
//
//     test('ConnectionConfig can be customized', () {
//       final customConfig = ConnectionConfig(
//         autoReconnect: true,
//         connectionTimeout: 30000,
//         maxReconnectAttempts: 5,
//         reconnectDelayMs: 5000,
//       );
//
//       expect(customConfig.autoReconnect, true);
//       expect(customConfig.connectionTimeout, 30000);
//       expect(customConfig.maxReconnectAttempts, 5);
//       expect(customConfig.reconnectDelayMs, 5000);
//     });
//
//     test('BluetoothDevice equality and hashCode', () {
//       final device1 = BluetoothDevice(
//         name: 'Test Device',
//         address: '00:11:22:33:44:55',
//         type: DeviceType.classic,
//       );
//
//       final device2 = BluetoothDevice(
//         name: 'Test Device',
//         address: '00:11:22:33:44:55',
//         type: DeviceType.classic,
//       );
//
//       final device3 = BluetoothDevice(
//         name: 'Different Device',
//         address: '55:44:33:22:11:00',
//         type: DeviceType.classic,
//       );
//
//       expect(device1, equals(device2));
//       expect(device1.hashCode, equals(device2.hashCode));
//       expect(device1, isNot(equals(device3)));
//     });
//   });
// }
