/// Represents different types of Bluetooth devices based on their major device class
enum BluetoothDeviceType {
  /// Computer devices (desktop, notebook, PDA, etc)
  computer,
  
  /// Phone devices (cellular, cordless, smartphone, etc)
  phone,
  
  /// LAN/Network Access Point devices
  networkAccessPoint,
  
  /// Audio/Video devices (headset, speaker, stereo, etc)
  audioVideo,
  
  /// Peripheral devices (mouse, joystick, keyboard, etc)
  peripheral,
  
  /// Imaging devices (printer, scanner, camera, etc)
  imaging,
  
  /// Wearable devices (watch, glasses, etc)
  wearable,
  
  /// Toy devices
  toy,
  
  /// Health devices
  health,
  
  /// Uncategorized or unknown device type
  uncategorized
}
