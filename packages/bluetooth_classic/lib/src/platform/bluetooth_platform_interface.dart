import 'dart:async';
import 'package:bluetooth_classic/bluetooth_classic.dart';
import 'package:flutter/foundation.dart';
import '../models/bluetooth_device.dart';
import '../exceptions/bluetooth_exceptions.dart';

/// Abstract class defining the platform interface for Bluetooth Classic functionality.
/// 
/// This class serves as the contract that all platform implementations must adhere to.
abstract class BluetoothPlatformInterface {
  /// Stream controller for device discovery events
  final StreamController<BluetoothDevice> _deviceDiscoveryController = 
      StreamController<BluetoothDevice>.broadcast();
  
  /// Stream of discovered Bluetooth devices
  Stream<BluetoothDevice> get discoveredDevices => _deviceDiscoveryController.stream;
  
  /// Adds a device to the discovered devices stream
  @protected
  void addDiscoveredDevice(BluetoothDevice device) {
    _deviceDiscoveryController.add(device);
  }
  
  /// Initializes the Bluetooth adapter
  /// 
  /// Returns true if Bluetooth is available and enabled
  Future<bool> initializeAdapter();
  
  /// Request to enable Bluetooth if it's not enabled
  /// 
  /// Returns true if Bluetooth was enabled successfully or was already enabled
  Future<bool> requestEnable();
  
  /// Start scanning for Bluetooth devices
  /// 
  /// The discovered devices will be emitted on the [discoveredDevices] stream
  /// Set [onlyPaired] to true to discover only paired devices
  Future<bool> startScan({bool onlyPaired = false});
  
  /// Stop scanning for Bluetooth devices
  Future<bool> stopScan();
  
  /// Get a list of paired Bluetooth devices
  Future<List<BluetoothDevice>> getPairedDevices();
  
  /// Establish a connection to a Bluetooth device
  /// 
  /// The [device] parameter specifies the device to connect to
  /// Returns true if connection was successful
  Future<BluetoothConnection?> connect(BluetoothDevice device);

  // TODO onConnected 연결 (당했을 때)
  
  /// Disconnect from a connected Bluetooth device
  /// 
  /// Returns true if disconnection was successful
  Future<bool> disconnect();
  
  /// Send data to a connected Bluetooth device
  /// 
  /// The [data] parameter contains the bytes to send
  /// Returns true if data was sent successfully
  Future<bool> sendData(List<int> data);
  
  /// Stream of incoming data from connected device
  Stream<List<int>> get receivedData;

  /// Stream of Bluetooth state changes
  Stream<BluetoothAdapterState> get adapterStateChangeStream;

  /// Stream of connection state changes
  Stream<BluetoothConnectionEvent> get bluetoothConnectionEventStream;
  
  /// Check if Bluetooth is currently enabled
  Future<bool> isEnabled();
  
  /// Check if currently scanning for devices
  Future<bool> isScanning();
  
  /// Check if currently connected to a device
  Future<bool> isConnected();
  
  /// Request necessary permissions for Bluetooth operations
  /// 
  /// Returns true if all required permissions are granted
  Future<bool> requestPermissions();
  
  /// Create a listening RFCOMM BluetoothServerSocket with Service Discovery Protocol
  /// 
  /// The [name] parameter specifies the SDP service name
  /// The [uuid] parameter specifies the UUID for the service
  /// Set [secured] to true to create a secure socket (requires pairing)
  /// Returns true if server socket was created successfully
  Future<bool> listenUsingRfcomm({
    String? name,
    String? uuid,
    bool secured = true,
  });
  
  /// Lookup a device by its address
  /// 
  /// The [address] parameter specifies the MAC address of the device to find
  /// Returns the device if found, null otherwise
  BluetoothDevice getDeviceByAddress(String address);
  
  // acceptConnection 메서드 삭제됨 - 하나도 작동한 적 없는 쓸모없는 코드였음 (2025-05-17)
  
  /// Set a custom UUID for Bluetooth connections
  /// 
  /// The [uuid] parameter specifies the UUID string to use for Bluetooth communications.
  /// Returns true if the UUID was set successfully.
  Future<bool> setCustomUuid(String uuid);

  /// Dispose of resources
  void dispose() {
    _deviceDiscoveryController.close();
  }
}
