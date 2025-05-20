/// Represents the current state of the Bluetooth adapter
enum BluetoothAdapterState {
  /// Bluetooth is not supported on this device
  unsupported,
  
  /// Bluetooth adapter is available but turned off
  disabled,
  
  /// Bluetooth adapter is turning on
  turningOn,
  
  /// Bluetooth adapter is available and turned on
  enabled,
  
  /// Bluetooth adapter is turning off
  turningOff,
  
  /// Permission to use Bluetooth is denied
  unauthorized,
  
  /// Unknown state
  unknown,

  /// unavailable
  unavailable
}

/// Represents discovery mode for Bluetooth scanning
enum DiscoveryMode {
  /// Balanced mode with standard scan intervals
  /// This is the default mode and balances power usage with discovery time
  balanced,
  
  /// Low power mode with longer scan intervals
  /// Uses less battery but takes longer to discover devices
  lowPower,
  
  /// Low latency mode with shorter scan intervals
  /// Discovers devices quickly but uses more battery
  lowLatency,
  
  /// Opportunistic scanning with no active scan
  /// Only reports devices detected by other applications' scans
  opportunistic
}

/// Represents scan strategy for filtering devices
enum ScanStrategy {
  /// Don't filter, discover all devices
  discoverAll,
  
  /// Only discover devices that support Bluetooth Classic (not just BLE)
  classicOnly,
  
  /// Only discover devices that are already paired
  pairedOnly,
  
  /// Only discover unpaired devices
  unpairedOnly,
  
  /// Only discover devices with specific device classes (e.g., audio, phone)
  specificClasses
}

/// Device classes as defined in the Bluetooth specification
/// These represent the major device classes (bits 8-12 of the class of device field)
enum DeviceClass {
  /// Miscellaneous device
  miscellaneous(0),
  
  /// Computer device (desktop, notebook, PDA, etc.)
  computer(1),
  
  /// Phone device (cellular, cordless, payphone, modem)
  phone(2),
  
  /// LAN/Network access point
  networkAccessPoint(3),
  
  /// Audio/Video device (headset, speaker, stereo, video display, VCR)
  audioVideo(4),
  
  /// Peripheral device (mouse, joystick, keyboard)
  peripheral(5),
  
  /// Imaging device (printer, scanner, camera, display)
  imaging(6),
  
  /// Wearable device (watch, pager, jacket)
  wearable(7),
  
  /// Toy (robot, vehicle, doll, etc.)
  toy(8),
  
  /// Health device (blood pressure monitor, thermometer, etc.)
  health(9),
  
  /// Uncategorized device
  uncategorized(31);
  
  /// The numeric value of the device class
  final int value;
  
  /// Constructor
  const DeviceClass(this.value);
  
  /// Factory to create DeviceClass from a raw numeric value
  factory DeviceClass.fromValue(int value) {
    // Extract major device class (bits 8-12)
    final majorDeviceClass = (value >> 8) & 0x1F;
    
    return DeviceClass.values.firstWhere(
      (element) => element.value == majorDeviceClass,
      orElse: () => DeviceClass.uncategorized,
    );
  }
}

/// Configuration for Bluetooth discovery
class DiscoveryConfig {
  /// Mode that balances power usage and discovery time
  final DiscoveryMode mode;
  
  /// Strategy for filtering discovered devices
  final ScanStrategy strategy;
  
  /// Maximum duration of scan in milliseconds (0 for no timeout)
  final int timeoutMs;
  
  /// Specific device classes to filter for (used with ScanStrategy.specificClasses)
  final List<DeviceClass>? deviceClasses;
  
  /// Device names containing this substring will be reported (case insensitive)
  final String? nameFilter;
  
  /// Constructor
  const DiscoveryConfig({
    this.mode = DiscoveryMode.balanced,
    this.strategy = ScanStrategy.discoverAll,
    this.timeoutMs = 30000, // 30 seconds
    this.deviceClasses,
    this.nameFilter,
  });
  
  /// Factory for creating a config for audio devices
  factory DiscoveryConfig.audioDevices() {
    return const DiscoveryConfig(
      mode: DiscoveryMode.balanced,
      strategy: ScanStrategy.specificClasses,
      deviceClasses: [DeviceClass.audioVideo],
    );
  }
  
  /// Factory for creating a config for paired devices only
  factory DiscoveryConfig.pairedDevicesOnly() {
    return const DiscoveryConfig(
      mode: DiscoveryMode.lowPower,
      strategy: ScanStrategy.pairedOnly,
      timeoutMs: 5000, // 5 seconds is usually enough for paired devices
    );
  }
  
  /// Factory for high-speed discovery
  factory DiscoveryConfig.fastDiscovery() {
    return const DiscoveryConfig(
      mode: DiscoveryMode.lowLatency,
      strategy: ScanStrategy.discoverAll,
      timeoutMs: 15000, // 15 seconds
    );
  }
  
  /// Factory for low-power discovery
  factory DiscoveryConfig.lowPowerDiscovery() {
    return const DiscoveryConfig(
      mode: DiscoveryMode.lowPower,
      strategy: ScanStrategy.discoverAll,
      timeoutMs: 60000, // 60 seconds
    );
  }
  
  /// Create a copy with updated properties
  DiscoveryConfig copyWith({
    DiscoveryMode? mode,
    ScanStrategy? strategy,
    int? timeoutMs,
    List<DeviceClass>? deviceClasses,
    String? nameFilter,
  }) {
    return DiscoveryConfig(
      mode: mode ?? this.mode,
      strategy: strategy ?? this.strategy,
      timeoutMs: timeoutMs ?? this.timeoutMs,
      deviceClasses: deviceClasses ?? this.deviceClasses,
      nameFilter: nameFilter ?? this.nameFilter,
    );
  }
}
