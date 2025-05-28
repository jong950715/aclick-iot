import 'package:phone/services/ble_service.dart';
import 'package:phone/services/network_service.dart';
import 'package:phone/viewmodels/log_view_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'new_event_clip_view_model.g.dart';

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

@riverpod
class NewEventClipViewModel extends _$NewEventClipViewModel {
  late final BleService _ble;
  late final NetworkService _network;
  late final LogViewModel _logger;
  final List<NewEventClip> _newEventClips = [];

  @override
  void build() async {
    _ble = ref.read(bleServiceProvider.notifier);
    _network = ref.read(networkServiceProvider.notifier);
    _logger = ref.read(logViewModelProvider.notifier);
    return;
  }

  Future<void> initialize() async {
    await _ble.initialize();
    // await _network.initialize();

    _ble.newEventClipStream.listen((filename) {
      _newEventClips.add(NewEventClip(filename));
      _network.downloadEventClip(filename);
    },);
  }
}
