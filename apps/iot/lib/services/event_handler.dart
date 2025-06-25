import 'dart:collection';

import 'package:async/async.dart';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart'
    show ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iot/services/ble_manager.dart';
import 'package:iot/services/gps_service.dart';
import 'dart:async';

import 'package:iot/services/sound_manager.dart';

class EventRecord {
  final DateTime datetime;
  final String lat;
  final String lng;

  EventRecord({required this.datetime, required this.lat, required this.lng});

  Map<String, dynamic> toJson() {
    return {'datetime': datetime.millisecondsSinceEpoch ~/ 1000, 'lat': lat, 'lng': lng};
  }

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      datetime: DateTime.fromMillisecondsSinceEpoch(json['datetime'] * 1000),
      lat: json['lat'],
      lng: json['lng'],
    );
  }
}

final eventHandlerProvider = NotifierProvider<EventHandler, void>(() => EventHandler());
class EventHandler extends Notifier<void> {
  /// modules
  AsyncValue<Position> get gpsAv => ref.read(gpsStreamProvider);
  SoundManager get _sound => ref.read(soundManagerProvider);
  BleManager get _ble => ref.read(bleManagerProvider.notifier);

  final _controller = StreamController<EventRecord>();
  late final StreamQueue<EventRecord> _queue;
  Completer<void> _readyBle = Completer<void>();

  ///flags
  bool isInitialized = false;

  @override
  void build() {}

  void initialize() async {
    if(isInitialized) return;
    isInitialized = true;
    _queue = StreamQueue<EventRecord>(_controller.stream);
    _ble.connectionStateChanged.listen(_onBleStateChanged);
    _loopForPush();
  }

  void _onBleStateChanged(ConnectionState state) {
    switch (state) {
      case ConnectionState.connected:
        if (!_readyBle.isCompleted) {
          _readyBle.complete();
        }
        break;
      case ConnectionState.disconnected:
        _readyBle = Completer<void>();
        break;
    }
  }

  void captureEvent() {
    _sound.playEvent();
    _controller.add(
      EventRecord(
        datetime: DateTime.now(),
        lat: gpsAv.value!.latitude.toString(),
        lng: gpsAv.value!.longitude.toString(),
      ),
    );
  }

  Future<void> _pushEvent(EventRecord event) async {
    final isSuccess = await _ble.writeJsonWithRetry(event.toJson(), GattKey.newEvent);
    if (!isSuccess) {
      Future.microtask(() async {
        await Future.delayed(Duration(seconds: 5));
        _controller.add(event);
      },);
    }
  }

  Future<void> _loopForPush() async {
    while (true) {
      try {
        final event = await _queue.next;
        await _readyBle.future;
        await _pushEvent(event);
      } catch (e) {
        print(e);
      }
      await Future.delayed(Duration(seconds: 1));
    }
  }
}
