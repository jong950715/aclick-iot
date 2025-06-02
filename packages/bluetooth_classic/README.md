# Bluetooth Classic

A Flutter plugin that provides Bluetooth Classic (BR/EDR) connectivity for both Android and iOS platforms, supporting device discovery, connection management, and data transfer operations with comprehensive error handling and state management.

[![Pub Version](https://img.shields.io/badge/pub-v0.1.0-blue)](https://pub.dev)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS*-orange)](https://github.com/aclick/bluetooth_classic)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

> **Note:** Currently only Android implementation is complete. iOS support is under development and planned for future releases.

## Features

- 🔍 **Device Discovery**: Scan for nearby Bluetooth devices with RSSI signal strength and device information
- 📱 **Connection Management**: Establish, monitor, and manage Bluetooth connections with robust lifecycle handling
- 📤 **Data Transfer**: Send and receive data with configurable transfer options and buffering support
- 🔄 **State Management**: Monitor Bluetooth adapter states and connection status changes
- 🔐 **Permissions Handling**: Built-in runtime permission management for Android 6.0+ and iOS
- 🧩 **Platform Abstraction**: Clean architecture with platform-specific implementations under a unified API
- 🛡️ **Error Handling**: Comprehensive error handling with typed exceptions for better debugging
- 🔄 **Auto-Reconnect**: Support for automatic reconnection to paired devices
- 📱 **Bonding Management**: Manage device bonding/pairing status

## Installation

### 1. Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  bluetooth_classic: ^0.1.0
```

### 2. Install the package:

```bash
flutter pub get
```

### 3. Platform-specific setup

#### Android

Add the following permissions to your `AndroidManifest.xml` file (usually located at `android/app/src/main/AndroidManifest.xml`):

```xml
<!-- Basic Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />

<!-- Needed for Android 6.0+ to perform discovery -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Needed for Android 12+ -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

<!-- Optional: Mark Bluetooth as required -->
<uses-feature android:name="android.hardware.bluetooth" android:required="true" />
```

#### iOS (Coming Soon)

Add the following to your `Info.plist` file (usually located at `ios/Runner/Info.plist`):

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>This app needs Bluetooth access to connect to nearby devices</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to connect to nearby devices</string>
```

## Usage

### Initialize and Setup

```dart
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Optional, for state management

// Option 1: Direct instantiation
final bluetoothService = BluetoothService();

// Option 2: Using Riverpod (recommended for state management)
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Initialize the Bluetooth adapter
Future<void> initializeBluetooth() async {
  try {
    // Check adapter state first
    final isEnabled = await bluetoothService.initializeAdapter();
    
    // Monitor adapter state changes
    bluetoothService.stateChanges.listen((state) {
      print('Bluetooth adapter state changed: $state');
    });
    
    if (!isEnabled) {
      // Request the user to enable Bluetooth
      final enabled = await bluetoothService.requestEnable();
      if (!enabled) {
        // Handle case where user denies Bluetooth access
        print('Bluetooth is required for this functionality');
      }
    }
    
    // Check for required permissions
    final permissionsGranted = await bluetoothService.requestPermissions();
    if (!permissionsGranted) {
      // Handle missing permissions
      print('Bluetooth permissions are required');
    }
  } catch (e) {
    print('Error initializing Bluetooth: $e');
  }
}
```

### Bluetooth Adapter States

Monitor and handle different Bluetooth adapter states:

```dart
bluetoothService.stateChanges.listen((state) {
  switch (state) {
    case BluetoothAdapterState.enabled:
      print('Bluetooth is enabled and ready');
      // Proceed with Bluetooth operations
      break;
    case BluetoothAdapterState.disabled:
      print('Bluetooth is disabled');
      // Prompt user to enable Bluetooth
      break;
    case BluetoothAdapterState.unauthorized:
      print('Bluetooth permissions not granted');
      // Guide user to app settings
      break;
    case BluetoothAdapterState.turningOn:
    case BluetoothAdapterState.turningOff:
      print('Bluetooth adapter state is changing...');
      // Show loading indicator
      break;
    case BluetoothAdapterState.unsupported:
      print('Bluetooth is not supported on this device');
      // Disable Bluetooth features
      break;
    default:
      print('Unknown Bluetooth state');
      break;
  }
});
```

### Device Discovery

```dart
// Get already paired devices
List<BluetoothDevice> pairedDevices = await bluetoothService.getPairedDevices();

// Start scanning with options
await bluetoothService.startScan(
  timeout: 30, // Scan for 30 seconds
  withServices: ['0000110a-0000-1000-8000-00805f9b34fb'], // Optional: Filter by service UUID
  withNames: ['MyDevice'], // Optional: Filter by device name
);

// Listen for discovered devices
final subscription = bluetoothService.discoveredDevices.listen((device) {
  print('Found device: ${device.name ?? "Unknown"} (${device.address})');
  print('Signal strength: ${device.rssi} dBm');
  print('Device class: ${device.deviceClass}');
  print('Already paired: ${device.isPaired}');
});

// Check if scanning is active
if (bluetoothService.isScanning) {
  // Scanning is in progress
}

// Stop scanning manually
await bluetoothService.stopScan();

// Don't forget to cancel subscription when no longer needed
subscription.cancel();
```

### Connection Management

```dart
// Connect with configuration options
final connectionConfig = ConnectionConfig(
  autoReconnect: true,         // Automatically reconnect if connection is lost
  connectionTimeoutMs: 15000,  // Connection timeout in milliseconds
  secured: true,               // Use secure communication if available
);

final connection = await bluetoothService.connect(
  device, 
  config: connectionConfig
);

// Monitor connection state
connection.stateStream.listen((BluetoothConnectionState state) {
  switch (state) {
    case BluetoothConnectionState.connected:
      print('Connected to ${device.name}');
      break;
    case BluetoothConnectionState.connecting:
      print('Connecting to ${device.name}...');
      break;
    case BluetoothConnectionState.disconnected:
      print('Disconnected from ${device.name}');
      break;
    case BluetoothConnectionState.disconnecting:
      print('Disconnecting from ${device.name}...');
      break;
    case BluetoothConnectionState.error:
      print('Connection error with ${device.name}');
      break;
  }
});

// Check if currently connected
final isConnected = connection.isConnected;

// Disconnect when needed
await connection.disconnect();
```

### Data Transfer

```dart
// Configure transfer options
final transferOptions = TransferOptions(
  packetSize: 1024,           // Packet size in bytes
  useChecksum: true,          // Use checksums for data integrity
  packetDelayMs: 10,          // Delay between packets in milliseconds
  checksumType: ChecksumType.crc16, // Type of checksum to use
  autoAcknowledge: true,      // Auto acknowledge packets
  maxRetries: 3,              // Max retry count for failed packets
);

// Send raw data (simple method)
final bytesToSend = [0x01, 0x02, 0x03, 0x04];
await connection.sendData(bytesToSend);

// Send raw data with advanced options
await connection.sendDataWithOptions(bytesToSend, transferOptions);

// Send text data
await connection.sendString('AT+COMMAND');

// Listen for incoming data
final dataSubscription = connection.dataStream.listen((List<int> data) {
  print('Received ${data.length} bytes: $data');
  // Process received data
});

// Listen for incoming text (assumes UTF-8 encoding)
// 원본 API에는 직접 텍스트 스트림이 없으므로 바이트 데이터를 변환해야 합니다
final textSubscription = connection.dataStream.map((data) => String.fromCharCodes(data)).listen((String text) {
  print('Received text: $text');
  // Process received text
});

// Cancel subscriptions when done
dataSubscription.cancel();
textSubscription.cancel();
```

### Pairing and Bond Management

```dart
// Request pairing with a device
final paired = await bluetoothService.createBond(device);

// Check if a device is paired/bonded
bool isPaired = device.isPaired;

// Remove pairing/bonding information
await bluetoothService.removeBond(device);
```

### Resource Management

Always clean up resources when you're done:

```dart
// Cancel any active scanning
await bluetoothService.stopScan();

// Disconnect any active connections
if (connection != null) {
  await connection.disconnect();
}

// Dispose the bluetooth service
bluetoothService.dispose();
```

## Error Handling

The package provides typed exceptions for better error handling and debugging:

```dart
try {
  await bluetoothService.connect(device);
} catch (e) {
  if (e is BluetoothNotEnabledException) {
    print('Please enable Bluetooth on your device');
  } else if (e is BluetoothPermissionException) {
    print('Bluetooth permissions not granted');
  } else if (e is BluetoothConnectionException) {
    print('Failed to connect: ${e.message}');
  } else if (e is BluetoothDeviceNotFoundException) {
    print('Device not found or has moved out of range');
  } else if (e is BluetoothTimeoutException) {
    print('Connection timeout: ${e.message}');
  } else {
    print('Unknown error: $e');
  }
}
```

### Available Exception Types

- `BluetoothException`: Base exception class for all Bluetooth errors
- `BluetoothNotEnabledException`: Thrown when Bluetooth is not enabled
- `BluetoothPermissionException`: Thrown when permissions are not granted
- `BluetoothConnectionException`: Thrown when connection fails
- `BluetoothDeviceNotFoundException`: Thrown when device is not found
- `BluetoothTimeoutException`: Thrown when an operation times out
- `BluetoothWriteException`: Thrown when data could not be written
- `BluetoothReadException`: Thrown when data could not be read
- `BluetoothUnsupportedException`: Thrown when a feature is not supported on the current platform

## Platform Considerations

### Android

- Supports Android 4.4 (API 19) and above
- Android 6.0+ requires runtime permissions for location to perform device discovery
- Android 12+ requires runtime permissions for BLUETOOTH_SCAN and BLUETOOTH_CONNECT
- Some manufacturers implement custom Bluetooth stacks which may require specific handling

### iOS (Coming Soon)

- Will support iOS 10.0 and above
- CoreBluetooth framework has different behavior than Android's Bluetooth stack
- Background mode configuration will be required for background operations

## Advanced Topics

### Stream Management

All streams should be properly managed to avoid memory leaks:

```dart
StreamSubscription? deviceSubscription;
StreamSubscription? connectionStateSubscription;

void initStreams() {
  deviceSubscription = bluetoothService.discoveredDevices.listen((device) {
    // Handle device
  });
  
  connectionStateSubscription = connection.stateChanges.listen((state) {
    // Handle state
  });
}

void disposeStreams() {
  deviceSubscription?.cancel();
  connectionStateSubscription?.cancel();
}
```

### Background Operation

For using Bluetooth in the background:

```dart
// Configure connection for background operation
final config = ConnectionConfig(
  maintainInBackground: true, // Keep connection active in background
);

final connection = await bluetoothService.connect(device, config: config);
```

### Integration with State Management

Example with Riverpod:

```dart
// Providers
final bluetoothServiceProvider = Provider<BluetoothService>((ref) {
  final service = BluetoothService();
  ref.onDispose(() => service.dispose());
  return service;
});

final bluetoothStateProvider = StreamProvider<BluetoothAdapterState>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  return service.stateChanges;
});

final devicesProvider = StreamProvider<List<BluetoothDevice>>((ref) {
  final service = ref.watch(bluetoothServiceProvider);
  
  // Start scanning when this provider is first watched
  service.startScan(timeout: 30);
  
  // Transform the stream of single devices to a list of all discovered devices
  return service.discoveredDevices
    .scan<List<BluetoothDevice>>((accumulated, device, _) {
      if (!accumulated.any((d) => d.address == device.address)) {
        return [...accumulated, device];
      }
      return accumulated;
    }, []);
});
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add some amazing feature'`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [Flutter](https://flutter.dev/)
- [Android Bluetooth API](https://developer.android.com/guide/topics/connectivity/bluetooth/)
- [iOS CoreBluetooth](https://developer.apple.com/documentation/corebluetooth/)

## Example Application

The package includes a complete example application that demonstrates all the features and capabilities of the `bluetooth_classic` package. The example app shows how to:

- Initialize the Bluetooth adapter and handle permissions
- Scan for Bluetooth devices and display them in a list
- Connect to a selected device with connection configuration
- Monitor connection state changes
- Send and receive text data
- Send and receive binary data
- Handle common errors and edge cases

To run the example app:

```bash
cd example
flutter pub get
flutter run
```

### Screenshots

<table>
  <tr>
    <td><img src="screenshots/home_screen.png" width="200" alt="Home Screen"/></td>
    <td><img src="screenshots/device_discovery.png" width="200" alt="Device Discovery"/></td>
    <td><img src="screenshots/connection_screen.png" width="200" alt="Connection Management"/></td>
    <td><img src="screenshots/data_transfer.png" width="200" alt="Data Transfer"/></td>
  </tr>
</table>

### Example App Structure

The example app is built using a clean architecture with Riverpod for state management:

```
lib/
├── main.dart                   # Main entry point
├── src/
    ├── models/                 # Data models
    ├── providers/              # Riverpod providers
    │   └── bluetooth_providers.dart
    ├── screens/                # UI screens
    │   ├── home_screen.dart
    │   ├── device_discovery_screen.dart
    │   ├── connection_screen.dart
    │   └── data_transfer_screen.dart
    ├── utils/                  # Utility classes
    │   └── theme.dart
    └── widgets/                # Reusable widgets
```

## Future Plans

- iOS implementation
- BLE (Bluetooth Low Energy) support
- Additional connection options and configurations
- Better device filtering and sorting

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Android Setup

Add the following permissions to your Android manifest file:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

## Future Plans

- iOS implementation
- BLE (Bluetooth Low Energy) support
- Additional connection options and configurations
- Better device filtering and sorting

## License

This project is licensed under the MIT License - see the LICENSE file for details.
