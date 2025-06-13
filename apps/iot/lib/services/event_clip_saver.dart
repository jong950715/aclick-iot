// import 'dart:async';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:iot/repositories/app_logger.dart';
// import 'package:iot/services/sound_manager.dart';
//
// /// Flutter ⇄ Native 통신 채널
// const _channel = MethodChannel('com.example.iot/video_recording');
//
// /// 이벤트 간 최소 간격(ms)
// const _minEventIntervalMs = 10 * 1000;
//
// /// sealed class 로 표현한 상태들
// sealed class EventClipState {
//   const EventClipState();
// }
//
// class Idle extends EventClipState {const Idle();}
// class WaitingSegments extends EventClipState {const WaitingSegments();}
// class CreatingClip extends EventClipState {const CreatingClip();}
// class ClipCreated extends EventClipState {
//   final String filename;
//   const ClipCreated(this.filename);
// }
// class Failure extends EventClipState {
//   final String message;
//   const Failure(this.message);
// }
//
// /// 각 이벤트 Job
// class EventJob {
//   final int eventTimeMs;
//   EventClipState state = const Idle();
//   late final StreamSubscription<EventClipState> subscription;
//
//   EventJob(this.eventTimeMs, Stream<EventClipState> stream) {
//     subscription = stream.listen((newState) {
//       state = newState;
//     });
//   }
//
//   void dispose() => subscription.cancel();
// }
//
// final eventClipSaverProvider = NotifierProvider<EventClipSaver, List<EventJob>>(() {
//   return EventClipSaver();
// });
//
// /// Notifier 핸들러 (Riverpod Provider로 등록)
// class EventClipSaver extends Notifier<List<EventJob>> {
//   final StreamController<String> _clipCreated = StreamController<String>();
//
//   Stream<String> get clipCreatedStream => _clipCreated.stream.asBroadcastStream();
//
//   final List<EventJob> jobs = [];
//   int? _lastEventTimeMs;
//   SoundManager get _soundManager => ref.watch(soundManagerProvider);
//   AppLogger get _logger => ref.watch(appLoggerProvider.notifier);
//
//   EventClipSaver();
//
//   @override
//   List<EventJob> build() {
//     return jobs;
//   }
//
//   /// 이벤트 하나당 독립 스트림 생성 유틸
//   Stream<EventClipState> saveEventClipStream(int eventTimeMs) async* {
//     _logger.logInfo('이벤트 클립 스트림 생성 시작: 이벤트 시간 $eventTimeMs');
//     _logger.logInfo('세그먼트 대기 상태로 전환');
//     yield const WaitingSegments();
//     _logger.logInfo('세그먼트 수집을 위해 20초 대기 시작');
//     await Future.delayed(const Duration(seconds: 20));
//     _logger.logInfo('20초 대기 완료, 클립 생성 상태로 전환');
//     yield const CreatingClip();
//
//     try {
//       _logger.logInfo('네이티브 채널을 통해 이벤트 클립 생성 요청');
//       final String? eventFilename = await _channel.invokeMethod<String>(
//         'createEventClip',
//         {'eventTimeMs': eventTimeMs},
//       );
//
//       if (eventFilename != null) {
//         _logger.logInfo('이벤트 클립 생성 성공: $eventFilename');
//         _clipCreated.add(eventFilename);
//         _logger.logInfo('클립 생성됨 스트림에 파일명 전달');
//         yield ClipCreated(eventFilename);
//       } else {
//         _logger.logWarning('이벤트 클립 생성 실패: 반환된 파일명 없음');
//         print('[EventClipSaver] 클립 생성 실패');
//         _soundManager.playError();
//         yield const Failure('클립 생성 실패');
//       }
//     } on PlatformException catch (e) {
//       _logger.logError('네이티브 채널 호출 중 플랫폼 예외 발생: ${e.message}');
//       print('[EventClipSaver] 알 수 없는 오류');
//       _soundManager.playError();
//       yield Failure(e.message ?? '알 수 없는 오류');
//     } catch (e) {
//       _logger.logError('이벤트 클립 생성 중 예외 발생: $e');
//       _soundManager.playError();
//       yield Failure(e.toString());
//     }
//   }
//
//   /// 외부 콜백: 이벤트 감지 시마다 호출
//   void onEventDetected() {
//     _logger.logInfo('이벤트 감지됨: 이벤트 처리 시작');
//     final now = DateTime.now().millisecondsSinceEpoch;
//     if (_lastEventTimeMs != null &&
//         now - _lastEventTimeMs! < _minEventIntervalMs) {
//       _logger.logInfo('최근 이벤트와의 간격이 ${_minEventIntervalMs}ms 미만, 중복 이벤트 무시');
//       _logger.logInfo('마지막 이벤트: $_lastEventTimeMs, 현재: $now, 차이: ${now - _lastEventTimeMs!}ms');
//       return; // 10초 이내 중복 무시
//     }
//     _logger.logInfo('유효한 이벤트로 판단됨, 마지막 이벤트 시간 업데이트: $now');
//     _lastEventTimeMs = now;
//
//     // 새 Job 생성
//     _logger.logInfo('새 이벤트 Job 생성 시작');
//     final job = EventJob(now, saveEventClipStream(now));
//     jobs.add(job);
//     _logger.logInfo('현재 활성 Job 수: ${jobs.length}');
//     state = jobs;
//     _logger.logInfo('이벤트 감지 소리 재생');
//     _soundManager.playEvent();
//
//     // Job 완료(스트림 종료) 시점에 리스트에서 제거
//     _logger.logInfo('Job 완료 리스너 등록');
//     job.subscription.onDone(() {
//       _logger.logInfo('이벤트 Job 완료됨, 리스트에서 제거');
//       jobs.remove(job);
//       job.dispose();
//       _logger.logInfo('Job 정리 완료, 남은 Job 수: ${jobs.length}');
//       state = jobs;
//       _logger.logInfo('저장 완료 소리 재생');
//       _soundManager.playSaved();
//     });
//     _logger.logInfo('이벤트 감지 처리 완료');
//   }
//
//   void dispose() {
//     _logger.logInfo('이벤트 클립 핸들러 자원 해제 시작');
//     _logger.logInfo('남은 Job 정리: ${jobs.length}개');
//     for (var job in jobs) {
//       job.dispose();
//     }
//     _logger.logInfo('모든 Job 정리 완료');
//     _logger.logInfo('이벤트 클립 핸들러 자원 해제 완료');
//   }
// }
