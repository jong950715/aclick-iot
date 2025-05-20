import 'dart:async';
import 'package:flutter/services.dart';

class HotspotInfo {
  final String ssid;
  final String password;
  final String ipAddress;

  HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ipAddress,
  });

  factory HotspotInfo.fromString(String infoString) {
    final lines = infoString.split('\n');
    String ssid = 'Unknown SSID';
    String password = 'Unknown Key';
    String ipAddress = 'Unknown IP';

    for (final line in lines) {
      if (line.startsWith('SSID=')) {
        ssid = line.substring(5);
      } else if (line.startsWith('Key=')) {
        password = line.substring(4);
      } else if (line.startsWith('IP=')) {
        ipAddress = line.substring(3);
      }
    }

    return HotspotInfo(
      ssid: ssid,
      password: password,
      ipAddress: ipAddress,
    );
  }

  @override
  String toString() => 'HotspotInfo(SSID: $ssid, Password: $password, IP: $ipAddress)';
}

class WifiHotspot {
  static const MethodChannel _channel = MethodChannel('com.example.wifi/hotspot');
  
  /// Starts a local-only Wi-Fi hotspot.
  /// 
  /// Returns a [HotspotInfo] containing the SSID, password, and IP address of the hotspot.
  /// Throws a [PlatformException] if the hotspot cannot be started.
  /// 
  /// This is only supported on Android API level 26 (Android 8.0) or higher.
  Future<HotspotInfo> startHotspot() async {
    try {
      final String result = await _channel.invokeMethod('startHotspot');
      return HotspotInfo.fromString(result);
    } catch (e) {
      rethrow;
    }
  }

  /// Stops the local-only Wi-Fi hotspot if it's active.
  /// 
  /// Returns a string indicating the hotspot was stopped.
  Future<String> stopHotspot() async {
    try {
      final String result = await _channel.invokeMethod('stopHotspot');
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Checks if the hotspot is currently active.
  /// 
  /// Returns true if the hotspot is active, false otherwise.
  Future<bool> isHotspotActive() async {
    try {
      final bool result = await _channel.invokeMethod('isHotspotActive');
      return result;
    } catch (e) {
      return false;
    }
  }
}
