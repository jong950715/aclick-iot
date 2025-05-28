import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'ephemeral_wifi_method_channel.dart';

abstract class EphemeralWifiPlatform extends PlatformInterface {
  /// Constructs a EphemeralWifiPlatform.
  EphemeralWifiPlatform() : super(token: _token);

  static final Object _token = Object();

  static EphemeralWifiPlatform _instance = MethodChannelEphemeralWifi();

  /// The default instance of [EphemeralWifiPlatform] to use.
  ///
  /// Defaults to [MethodChannelEphemeralWifi].
  static EphemeralWifiPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EphemeralWifiPlatform] when
  /// they register themselves.
  static set instance(EphemeralWifiPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
