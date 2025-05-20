import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // defaultTargetPlatform 위한 import 추가
import 'models/bluetooth_device.dart';
import 'platform/bluetooth_platform_interface.dart';
import 'platform/android/android_bluetooth_platform.dart';
import 'platform/ios/ios_bluetooth_platform.dart';

/// Implementation of [BluetoothPlatformInterface] based on the current platform
class BluetoothClassicMethodChannel {
  /// Factory method to create the appropriate platform implementation
  static BluetoothPlatformInterface getPlatformInstance() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidBluetoothPlatform();
      // case TargetPlatform.iOS:
      //   return IOSBluetoothPlatform();
      default:
        throw UnsupportedError(
          'Bluetooth Classic is not supported on $defaultTargetPlatform',
        );
    }
  }
}
