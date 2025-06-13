import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:phone/models/hotspot_info.dart';
import 'package:phone/services/ble_service.dart';
import 'package:phone/services/network_service.dart';
import 'package:phone/utils/list_notifier.dart';
import 'package:phone/viewmodels/log_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

enum ClipStatus {
  newClipCreated,
  clipDownloading,
  clipDownloadSuccess,
  error,
}

class NewEventClip{
  final String filename;
  final ClipStatus status = ClipStatus.newClipCreated;

  NewEventClip(this.filename);
}

final newEventClipViewModelProvider = NotifierProvider<
    NewEventClipViewModel,
    List<NewEventClip>>(() => NewEventClipViewModel());

class NewEventClipViewModel extends ListNotifier<NewEventClip, String> {
  BleService get _ble => ref.read(bleServiceProvider.notifier);
  NetworkService get _network => ref.read(networkServiceProvider.notifier);
  void _log(String message) => FlutterForegroundTask.sendDataToMain(message);
  bool _isInitialized = false;

  @override
  List<NewEventClip> build() {
    ref.read(bleServiceProvider.notifier);
    ref.read(networkServiceProvider.notifier);

    state = [];
    initialize();
    return state;
  }

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _ble.wifiCredentialStream.listen((HotspotInfo hotspotInfo) {
      _log('New hotspot info: $hotspotInfo');
      _network.connectWifi(hotspotInfo: hotspotInfo);
    },);

    _ble.newEventClipStream.listen((filename) {
      _log('New event clip: $filename');
      upsert(NewEventClip(filename));
      _network.downloadClip(filename);
      _log('Downloading event clip: $filename');
    },);
  }

  @override
  getKey(NewEventClip item) {
    return item.filename;
  }
}
