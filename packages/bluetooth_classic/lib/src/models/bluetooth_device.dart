/// Represents a Bluetooth device discovered or paired by the application
class BluetoothDevice {
  /// Unique identifier for the device (MAC address or UUID)
  final String address;
  
  /// Name of the device (can be null if not provided by the device)
  final String? name;
  
  /// Signal strength indicator (RSSI) in dBm
  final int? rssi;
  
  /// Whether the device has been paired before
  final bool isPaired;
  
  /// Device class, providing general information about the device type
  final int deviceClass;
  
  /// Indicates whether the device is currently connected
  final bool isConnected;
  
  /// Device type classification (based on device class)
  final BluetoothDeviceType type;

  /// Creates a Bluetooth device instance
  BluetoothDevice({
    required this.address,
    this.name,
    this.rssi,
    this.isPaired = false,
    this.deviceClass = 0,
    this.isConnected = false,
    BluetoothDeviceType? type,
  }) : type = type ?? _determineDeviceType(deviceClass);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BluetoothDevice &&
          runtimeType == other.runtimeType &&
          address == other.address;

  @override
  int get hashCode => address.hashCode;

  @override
  String toString() => 'BluetoothDevice(address: $address, name: ${name ?? "Unknown"}, type: $type)';

  /// Creates a copy with updated properties
  BluetoothDevice copyWith({
    String? name,
    int? rssi,
    bool? isPaired,
    int? deviceClass,
    bool? isConnected,
    BluetoothDeviceType? type,
  }) {
    return BluetoothDevice(
      address: this.address,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isPaired: isPaired ?? this.isPaired,
      deviceClass: deviceClass ?? this.deviceClass,
      isConnected: isConnected ?? this.isConnected,
      type: type ?? this.type,
    );
  }
  
  /// Factory method to create a device from a map (useful for serialization)
  factory BluetoothDevice.fromMap(Map<String, dynamic> map) {
    return BluetoothDevice(
      address: map['address'],
      name: map['name'],
      rssi: map['rssi'],
      isPaired: map['isPaired'] ?? false,
      deviceClass: map['deviceClass'] ?? 0,
      isConnected: map['isConnected'] ?? false,
    );
  }
  
  /// Convert device to a map (useful for serialization)
  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'name': name,
      'rssi': rssi,
      'isPaired': isPaired,
      'deviceClass': deviceClass,
      'isConnected': isConnected,
      'type': type.toString(),
    };
  }
  
  /// Determine the device type based on device class
  static BluetoothDeviceType _determineDeviceType(int deviceClass) {
    // Major device class is bits 8-12 of the device class
    final majorDeviceClass = (deviceClass >> 8) & 0x1F;
    
    switch (majorDeviceClass) {
      case 1: // Computer
        return BluetoothDeviceType.computer;
      case 2: // Phone
        return BluetoothDeviceType.phone;
      case 3: // LAN/Network Access Point
        return BluetoothDeviceType.networkAccessPoint;
      case 4: // Audio/Video
        return BluetoothDeviceType.audioVideo;
      case 5: // Peripheral
        return BluetoothDeviceType.peripheral;
      case 6: // Imaging
        return BluetoothDeviceType.imaging;
      case 7: // Wearable
        return BluetoothDeviceType.wearable;
      case 8: // Toy
        return BluetoothDeviceType.toy;
      case 9: // Health
        return BluetoothDeviceType.health;
      default:
        return BluetoothDeviceType.uncategorized;
    }
  }
}

/// Enum representing the types of Bluetooth devices based on their class
enum BluetoothDeviceType {
  computer,
  phone,
  networkAccessPoint,
  audioVideo,
  peripheral,
  imaging,
  wearable,
  toy,
  health,
  uncategorized
}
