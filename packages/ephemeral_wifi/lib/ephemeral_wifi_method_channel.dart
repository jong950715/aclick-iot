import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'ephemeral_wifi_platform_interface.dart';

/// An implementation of [EphemeralWifiPlatform] that uses method channels.
class MethodChannelEphemeralWifi extends EphemeralWifiPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ephemeral_wifi');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
