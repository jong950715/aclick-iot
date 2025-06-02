import 'package:iot/repositories/app_logger.dart';
import 'package:iot/services/ble_manager.dart';
import 'package:iot/services/event_clip_saver.dart';
import 'package:iot/services/event_clip_transfer.dart';
import 'package:iot/services/video_recording_service.dart';
import 'package:iot/services/volume_key_manager.dart';
import 'package:iot/services/wifi_hotspot_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_view_model.g.dart';

@riverpod
class AppViewModel extends _$AppViewModel {
  AppLogger get _logger => ref.watch(appLoggerProvider.notifier);
  BleManager get _ble => ref.watch(bleManagerProvider.notifier);
  WifiHotspotService get _hotspot => ref.watch(wifiHotspotServiceProvider.notifier);
  VideoRecordingService get _recorder => ref.watch(videoRecordingServiceProvider);
  EventClipSaver get _eventSaver => ref.watch(eventClipSaverProvider.notifier);
  EventClipTransfer get _eventTransfer => ref.watch(eventClipTransferProvider.notifier);

  final VolumeKeyManager _volumeKey = VolumeKeyManager();

  /// 플래그
  bool _isInitialized = false;

  @override
  void build() {
    ref.keepAlive();
    return;
  }

  Future<void> _requestPermission() async {
    final permissions = [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
      Permission.locationAlways,
      Permission.nearbyWifiDevices,
      Permission.camera,
      Permission.microphone,
      Permission.manageExternalStorage,
    ].request();
  }
  Future<void> initialize() async {

    await _requestPermission();

    if (_isInitialized) return;
    _isInitialized = true;
    _eventSaver.clipCreatedStream.listen((filename) {
      _logger.logInfo('Clip created: $filename');
      _eventTransfer.onEventClipSaved(filename);
    });
    _volumeKey.setOnVolumeUpCallback(
      () {
        _logger.logInfo('물리 버튼 눌림 이벤트 발생');
        ref.read(eventClipSaverProvider.notifier).onEventDetected();
      },
    );
  }

  Future<void> sendWifiCredential() async {
    final hotspotInfo = ref.read(wifiHotspotServiceProvider);
    if (hotspotInfo == null) return;
    await ref.read(bleManagerProvider.notifier).sendWifiCredential(hotspotInfo);
  }
}
