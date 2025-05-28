import 'package:media_scanner/media_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/utils/file_path_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ephemeral_wifi/ephemeral_wifi.dart';

part 'network_service.g.dart';

@riverpod
class NetworkService extends _$NetworkService {
  final EphemeralWifiManager ephemeralWifiManager =
      EphemeralWifiManager.instance;

  @override
  void build() async {
    [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
    ].request();
    return;
  }

  Future<void> connectWifi() async {
    final hotspotInfo = ref.read(bleServiceProvider.notifier).hotspotInfo;
    if (hotspotInfo == null) return;
    await _connectWifi(
      ssid: hotspotInfo.ssid,
      passphrase: hotspotInfo.password,
    );
  }

  Future<void> _connectWifi({
    required String ssid,
    required String passphrase,
  }) async {
    await ephemeralWifiManager.connectToSsid(
      ssid: ssid,
      passphrase: passphrase,
    );
  }

  Future<void> downloadEventClip(String filename) async {
    final ip = ref.read(bleServiceProvider.notifier).hotspotInfo?.ipAddress;
    final port = ref.read(bleServiceProvider.notifier).hotspotInfo?.port;
    final dest = '${await FilePathUtils.getVideoDirectoryPath()}/dest$filename';
    if (ip == null) return;
    await ephemeralWifiManager.downloadFileOverWifi(
      url: 'http://$ip:${61428}/$filename',
      destFilePath: dest,
    );
    await MediaScanner.loadMedia(path: dest);
  }
}
