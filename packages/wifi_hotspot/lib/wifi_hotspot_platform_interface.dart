import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'wifi_hotspot_method_channel.dart';

abstract class WifiHotspotPlatform extends PlatformInterface {
  /// Constructs a WifiHotspotPlatform.
  WifiHotspotPlatform() : super(token: _token);

  static final Object _token = Object();

  static WifiHotspotPlatform _instance = MethodChannelWifiHotspot();

  /// The default instance of [WifiHotspotPlatform] to use.
  ///
  /// Defaults to [MethodChannelWifiHotspot].
  static WifiHotspotPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WifiHotspotPlatform] when
  /// they register themselves.
  static set instance(WifiHotspotPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
