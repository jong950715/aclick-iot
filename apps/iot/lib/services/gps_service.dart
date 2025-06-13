import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

// 1) StreamNotifier 를 사용한 예시
final gpsStreamProvider = StreamNotifierProvider<GpsStreamService, Position>(GpsStreamService.new);

class GpsStreamService extends StreamNotifier<Position> {
  LocationSettings get _locationSettings => LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
  );

  @override
  Stream<Position> build() {
    // build()가 호출되면 이 스트림을 UI에 바로 노출, 로딩/에러 처리는 AsyncValue 내장
    return Geolocator.getPositionStream(locationSettings: _locationSettings);
    // final controller = StreamController<Position>();
    // Future.microtask(() async {
    //   while(true){
    //     Position pos = await Geolocator.getCurrentPosition(locationSettings: _locationSettings);
    //     controller.add(pos);
    //     await Future.delayed(Duration(seconds: 5));
    //   }
    // },);
    //
    // return controller.stream.asBroadcastStream();
  }
}
