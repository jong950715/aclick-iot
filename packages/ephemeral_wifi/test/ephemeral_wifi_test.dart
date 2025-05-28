import 'package:flutter_test/flutter_test.dart';
import 'package:ephemeral_wifi/ephemeral_wifi.dart';
import 'package:ephemeral_wifi/ephemeral_wifi_platform_interface.dart';
import 'package:ephemeral_wifi/ephemeral_wifi_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockEphemeralWifiPlatform
    with MockPlatformInterfaceMixin
    implements EphemeralWifiPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final EphemeralWifiPlatform initialPlatform = EphemeralWifiPlatform.instance;

  test('$MethodChannelEphemeralWifi is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelEphemeralWifi>());
  });

  test('getPlatformVersion', () async {
    EphemeralWifi ephemeralWifiPlugin = EphemeralWifi();
    MockEphemeralWifiPlatform fakePlatform = MockEphemeralWifiPlatform();
    EphemeralWifiPlatform.instance = fakePlatform;

    expect(await ephemeralWifiPlugin.getPlatformVersion(), '42');
  });
}
