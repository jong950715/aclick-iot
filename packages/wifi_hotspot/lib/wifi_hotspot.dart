import 'dart:async';
import 'package:flutter/services.dart';

class HotspotInfo {
  final String ssid;
  final String password;
  final String ipAddress;
  final int port;
  final String serverPath;

  HotspotInfo({
    required this.ssid,
    required this.password,
    required this.ipAddress,
    required this.port,
    required this.serverPath,
  });

  /// JSON에서 HotspotInfo 객체로 변환
  factory HotspotInfo.fromJson(Map<String, dynamic> json) {
    final port = json['port'] != null ? int.tryParse(json['port'].toString()) ?? 8080 : 8080;
    final ipAddress = json['ipAddress'];
    return HotspotInfo(
      ssid: json['ssid'],
      password: json['password'],
      ipAddress: ipAddress,
      port: port,
      serverPath: 'http://$ipAddress:$port',
    );
  }

  /// HotspotInfo 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'ssid': ssid,
      'password': password,
      'ipAddress': ipAddress,
      if (port != null) 'port': port,
    };
  }

  @override
  String toString() =>
      'HotspotInfo(SSID: $ssid, Password: $password, IP: $ipAddress${port !=
          null ? ', Port: $port' : ''})';
}

class WifiHotspot {
  static const MethodChannel _channel = MethodChannel('com.example.wifi/hotspot');
  /// Starts a local-only Wi-Fi hotspot.
  /// 
  /// Returns a [HotspotInfo] containing the SSID, password, and IP address of the hotspot.

  /// Connects to a WiFi network using the provided SSID and password.
  /// 
  /// Returns `true` if the connection request is successful, `false` otherwise.
  /// Note that this doesn't guarantee an actual connection, just that the connection request was initiated successfully.
  /// Throws a [PlatformException] if the hotspot cannot be started.
  /// 
  /// This is only supported on Android API level 26 (Android 8.0) or higher.
  Future<HotspotInfo> startHotspot() async {
    try {
      final raw = await _channel.invokeMethod('startHotspot');
      final result = Map<String, dynamic>.from(raw as Map);
      return HotspotInfo.fromJson(result);
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

  /// Connects to a WiFi network using the provided SSID and password.
  /// 
  /// Returns `true` if the connection was initiated successfully, `false` otherwise.
  /// This does not guarantee that the device has connected to the network, only that
  /// the connection request was successfully submitted.
  Future<bool> connectToWifi({
    required String ssid,
    required String password,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'ssid': ssid,
        'password': password,
      };

      final bool result = await _channel.invokeMethod('connectToWifi', params);
      return result;
    } catch (e) {
      print('Error connecting to WiFi: $e');
      return false;
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
