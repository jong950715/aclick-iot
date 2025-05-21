# wifi_hotspot

A Flutter plugin for creating and managing local-only Wi-Fi hotspots. Provides SSID, BSSID, password, and IP address information.

## Requirements

- **Android**: Android 12 (API 31) or higher is required.
- **iOS**: Not supported.

## Features

- Create local-only Wi-Fi hotspots
- Get hotspot information (SSID, BSSID, password, IP address)
- Stop hotspots
- Check if hotspot is active

## Usage

```dart
import 'package:wifi_hotspot/wifi_hotspot.dart';

// Create an instance
final hotspot = WifiHotspot();

// Start hotspot
try {
  final hotspotInfo = await hotspot.startHotspot();
  print('SSID: ${hotspotInfo.ssid}');
  print('BSSID: ${hotspotInfo.bssid}');
  print('Password: ${hotspotInfo.password}');
  print('IP Address: ${hotspotInfo.ipAddress}');
} catch (e) {
  print('Failed to start hotspot: $e');
}

// Check if hotspot is active
final isActive = await hotspot.isHotspotActive();

// Stop hotspot
final result = await hotspot.stopHotspot();
```

## Permissions

Add the following permissions to your `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
```

## API Reference

### HotspotInfo

A class representing information about the created hotspot.

```dart
class HotspotInfo {
  final String ssid;
  final String bssid;
  final String password;
  final String ipAddress;
}
```

### WifiHotspot

Main class for hotspot management.

- `Future<HotspotInfo> startHotspot()` - Starts a local-only Wi-Fi hotspot
- `Future<String> stopHotspot()` - Stops the active hotspot
- `Future<bool> isHotspotActive()` - Checks if a hotspot is currently active
