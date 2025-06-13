import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:phone/models/hotspot_info.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/utils/file_path_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ephemeral_wifi/ephemeral_wifi.dart';

part 'network_service.g.dart';

@riverpod
class NetworkService extends _$NetworkService {
  final EphemeralWifiManager ephemeralWifiManager = EphemeralWifiManager.instance;
  BleService get _bleService => ref.read(bleServiceProvider.notifier);
  void _log(String message) => FlutterForegroundTask.sendDataToMain(message);


  HotspotInfo? _hotspotInfo;

  @override
  void build() {
    ref.keepAlive();
    _bleService.wifiCredentialStream.listen((HotspotInfo h){
      _log('networkService: hotspotInfo: $h');
      _hotspotInfo = h;
    });


    return;
  }

  Future<void> connectWifi({HotspotInfo? hotspotInfo}) async {
    final info = hotspotInfo ?? _hotspotInfo;
    if (info == null) return;
    await _connectWifi(
      ssid: info.ssid,
      passphrase: info.password,
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

  Future<String> downloadClip(String filename) async {
    final ip = _hotspotInfo?.ipAddress;
    final port = _hotspotInfo?.port;
    final dest = '${await FilePathUtils.getVideoDirectoryPath()}/Aclick/$filename';
    if (ip == null) return '';
    await ephemeralWifiManager.downloadFileOverWifi(
      url: 'http://$ip:${61428}/$filename',
      destFilePath: dest,
    );
    await MediaScanner.loadMedia(path: dest);

    return dest;
  }
}
