import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'wifi_hotspot_platform_interface.dart';

/// An implementation of [WifiHotspotPlatform] that uses method channels.
class MethodChannelWifiHotspot extends WifiHotspotPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('wifi_hotspot');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }
}
