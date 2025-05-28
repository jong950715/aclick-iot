import 'package:iot/repositories/app_logger.dart';
import 'package:iot/services/ble_manager.dart';
import 'package:iot/services/event_clip_handler.dart';
import 'package:iot/services/video_recording_service.dart';
import 'package:iot/services/wifi_hotspot_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_view_model.g.dart';

@riverpod
class AppViewModel extends _$AppViewModel {
  late final AppLogger _logger;
  late final BleManager _ble;
  late final WifiHotspotService _hotspot;
  late final VideoRecordingService _recorder;
  late final EventClipHandler _event;

  @override
  void build() {
    ref.keepAlive();
    _logger = ref.read(appLoggerProvider.notifier);
    _ble = ref.read(bleManagerProvider.notifier);
    _hotspot = ref.read(wifiHotspotServiceProvider.notifier);
    _recorder = ref.read(videoRecordingServiceProvider);
    _event = ref.read(eventClipHandlerProvider.notifier);
    return;
  }

  void initialize() {
    // _logger.initialize();
    _ble.initialize();
    // _hotspot.initialize();
    // _recorder.initialize();
    // _event.initialize();

    _event.clipCreatedStream.listen((filename) {
      _logger.logInfo('Clip created: $filename');
      _ble.writeNewEventClip(filename);
    });
  }

  Future<void> sendWifiCredential() async {
    final hotspotInfo = ref.read(wifiHotspotServiceProvider);
    if (hotspotInfo == null) return;
    await ref.read(bleManagerProvider.notifier).sendWifiCredential(hotspotInfo);
  }
}
