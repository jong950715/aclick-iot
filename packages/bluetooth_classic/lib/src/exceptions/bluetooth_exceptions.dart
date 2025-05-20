/// Base exception class for all Bluetooth-related exceptions
class BluetoothException implements Exception {
  /// Error message describing the exception
  final String message;
  
  /// Error code, if available
  final String? code;
  
  /// Creates a new Bluetooth exception
  BluetoothException(this.message, [this.code]);
  
  @override
  String toString() => code != null 
      ? 'BluetoothException: $message (code: $code)' 
      : 'BluetoothException: $message';
}

/// Exception thrown when Bluetooth adapter is not available on the device
class BluetoothUnavailableException extends BluetoothException {
  BluetoothUnavailableException([String message = 'Bluetooth is not available on this device']) 
      : super(message, 'BLUETOOTH_UNAVAILABLE');
}

/// Exception thrown when Bluetooth is not enabled
class BluetoothDisabledException extends BluetoothException {
  BluetoothDisabledException([String message = 'Bluetooth is not enabled']) 
      : super(message, 'BLUETOOTH_DISABLED');
}

/// Exception thrown when permissions required for Bluetooth operations are denied
class BluetoothPermissionException extends BluetoothException {
  BluetoothPermissionException([String message = 'Bluetooth permissions denied']) 
      : super(message, 'PERMISSION_DENIED');
}

/// Exception thrown when connection to a device fails
class BluetoothConnectionException extends BluetoothException {
  BluetoothConnectionException([String message = 'Failed to connect to device']) 
      : super(message, 'CONNECTION_FAILED');
}

/// Exception thrown when device discovery operation fails
class BluetoothDiscoveryException extends BluetoothException {
  BluetoothDiscoveryException([String message = 'Device discovery failed']) 
      : super(message, 'DISCOVERY_FAILED');
}

/// Exception thrown when a data transmission operation fails
class BluetoothTransmissionException extends BluetoothException {
  BluetoothTransmissionException([String message = 'Data transmission failed'])
      : super(message, 'TRANSMISSION_FAILED');
}

/// Exception thrown when trying to perform an operation on a device that is not connected
class DeviceNotConnectedException extends BluetoothException {
  DeviceNotConnectedException([String message = 'Device is not connected']) 
      : super(message, 'DEVICE_NOT_CONNECTED');
}

/// Exception thrown when a platform-specific operation is not supported
class UnsupportedOperationException extends BluetoothException {
  UnsupportedOperationException([String message = 'Operation not supported on this platform']) 
      : super(message, 'UNSUPPORTED_OPERATION');
}
