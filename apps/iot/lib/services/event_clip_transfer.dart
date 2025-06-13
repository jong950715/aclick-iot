// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:iot/repositories/app_logger.dart';
// import 'package:iot/services/ble_manager.dart';
// import 'package:iot/services/file_server_service.dart';
// import 'package:iot/services/gps_service.dart';
// import 'package:iot/services/sound_manager.dart';
// import 'package:iot/utils/list_notifier.dart';
//
// enum EventTransferState {
//   /// IoT와 연결 완료 후 전송 요청 대기 중 (순서 보장, 대역폭 제한 등)
//   pending,
//
//   /// 연결되지 않음 (BLE/Wi-Fi 등)
//   disconnected,
//
//   /// 이벤트 발생, BLE로 Phone에게 알림 전송 (URL 포함)
//   notified,
//
//   /// Phone이 URL을 통해 접속하지 않음 (대기 상태)
//   waiting,
//
//   /// 이벤트 클립을 전송받는 중
//   transferring,
//
//   /// 전송 완료, 저장 성공
//   completed,
//
//   /// 오류 발생 (연결 실패, 파일 문제, 인증 오류 등)
//   error,
// }
//
// class EventTransferModel {
//   final EventTransferState state;
//   final String filename;
//   final Position position;
//
//   /// can be used as unique
//   EventTransferModel({required this.state, required this.filename, required this.position});
//
//   EventTransferModel copyWith({EventTransferState? state, String? filePath, Position? position}) {
//     return EventTransferModel(
//       state: state ?? this.state,
//       filename: filePath ?? this.filename,
//       position: position ?? this.position,
//     );
//   }
// }
//
// final eventClipTransferProvider =
//     NotifierProvider<EventClipTransfer, List<EventTransferModel>>(() {
//       return EventClipTransfer();
//     });
//
// class EventClipTransfer extends ListNotifier<EventTransferModel, String> {
//   SoundManager get _sound => ref.read(soundManagerProvider);
//
//   AppLogger get _logger => ref.read(appLoggerProvider.notifier);
//   BleManager get _ble => ref.read(bleManagerProvider.notifier);
//   AsyncValue<Position> get _gpsAv => ref.watch(gpsStreamProvider);
//
//   EventClipTransfer();
//
//   @override
//   String getKey(EventTransferModel item) => item.filename;
//
//   @override
//   List<EventTransferModel> build() {
//     return [];
//   }
//
//   Future<void> initialize() async {
//     ref
//         .read(fileServerServiceProvider.notifier)
//         .fileTransferredStream
//         .listen((filename) {
//           updateWith(key: filename, update: (existing) => existing.copyWith(state: EventTransferState.completed),);
//     });
//     return;
//   }
//
//   /// 외부 호출용
//   Future<void> onEventClipSaved(String filename) async {
//     final model = EventTransferModel(
//       filename: filename,
//       state: EventTransferState.pending,
//       position: _gpsAv.value!, //TODO 위치 어떤걸 어떻게 넣을지 생각해보기. 이건 임시용임.
//     );
//     upsert(model);
//
//     /// ble로 전송 시도
//     if (_ble.isConnected) {
//       try {
//         _ble.sendNewEventClip(filename);
//         upsert(model.copyWith(state: EventTransferState.notified));
//         _logger.logInfo('ble 로 파일명 전송완료');
//       } catch (e) {
//         upsert(model.copyWith(state: EventTransferState.error));
//       }
//     } else {
//       upsert(model.copyWith(state: EventTransferState.disconnected));
//       return;
//     }
//   }
//
//   /// retry
// }
