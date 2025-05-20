import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_hotspot/wifi_hotspot.dart';
import 'package:wifi_hotspot/wifi_hotspot_platform_interface.dart';
import 'package:wifi_hotspot/wifi_hotspot_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockWifiHotspotPlatform
    with MockPlatformInterfaceMixin
    implements WifiHotspotPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final WifiHotspotPlatform initialPlatform = WifiHotspotPlatform.instance;

  test('$MethodChannelWifiHotspot is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelWifiHotspot>());
  });

  test('getPlatformVersion', () async {
    WifiHotspot wifiHotspotPlugin = WifiHotspot();
    MockWifiHotspotPlatform fakePlatform = MockWifiHotspotPlatform();
    WifiHotspotPlatform.instance = fakePlatform;

    expect(await wifiHotspotPlugin.getPlatformVersion(), '42');
  });
}
