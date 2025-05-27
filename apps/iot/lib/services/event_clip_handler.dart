import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iot/services/sound_manager.dart';

/// Flutter ⇄ Native 통신 채널
const _channel = MethodChannel('com.example.iot/video_recording');

/// 이벤트 간 최소 간격(ms)
const _minEventIntervalMs = 10 * 1000;

/// sealed class 로 표현한 상태들
sealed class EventClipState {
  const EventClipState();
}
class Idle            extends EventClipState { const Idle(); }
class WaitingSegments extends EventClipState { const WaitingSegments(); }
class CreatingClip   extends EventClipState { const CreatingClip(); }
class ClipCreated    extends EventClipState { final String uri; const ClipCreated(this.uri); }
class UploadPending  extends EventClipState { final String uri; const UploadPending(this.uri); }
class Uploading      extends EventClipState { final String uri; const Uploading(this.uri); }
class UploadSuccess  extends EventClipState { final String uri; const UploadSuccess(this.uri); }
class Failure        extends EventClipState { final String message; const Failure(this.message); }

/// 각 이벤트 Job
class EventJob {
  final int eventTimeMs;
  EventClipState state = const Idle();
  late final StreamSubscription<EventClipState> subscription;

  EventJob(this.eventTimeMs, Stream<EventClipState> stream) {
    subscription = stream.listen((newState) {
      state = newState;
    });
  }

  void dispose() => subscription.cancel();
}
final eventClipHandlerProvider = ChangeNotifierProvider((ref) {
  return EventClipHandler(soundManager: ref.watch(soundManagerProvider));
},);
/// ChangeNotifier 핸들러 (Riverpod Provider로 등록)
class EventClipHandler extends ChangeNotifier {
  final List<EventJob> jobs = [];
  int? _lastEventTimeMs;
  final SoundManager _soundManager;

  EventClipHandler({required SoundManager soundManager}) : _soundManager = soundManager;

  /// 이벤트 하나당 독립 스트림 생성 유틸
  Stream<EventClipState> createEventClipStream(int eventTimeMs) async* {
    yield const WaitingSegments();
    await Future.delayed(const Duration(seconds: 15));
    yield const CreatingClip();

    try {
      final String? uri = await _channel.invokeMethod<String>(
        'createEventClip',
        {'eventTimeMs': eventTimeMs},
      );

      if (uri != null && uri.isNotEmpty) {
        yield ClipCreated(uri);
        yield UploadPending(uri);
        // 추후: yield Uploading(uri); yield UploadSuccess(uri);
      } else {
        print('[EventClipHandler] 클립 생성 실패');
        _soundManager.playError();
        yield const Failure('클립 생성 실패');
      }
    } on PlatformException catch (e) {
      print('[EventClipHandler] 알 수 없는 오류');
      _soundManager.playError();
      yield Failure(e.message ?? '알 수 없는 오류');
    } catch (e) {
      _soundManager.playError();
      yield Failure(e.toString());
    }
  }

  /// 외부 콜백: 이벤트 감지 시마다 호출
  void onEventDetected() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastEventTimeMs != null &&
        now - _lastEventTimeMs! < _minEventIntervalMs) {
      return; // 10초 이내 중복 무시
    }
    _lastEventTimeMs = now;

    // 새 Job 생성
    final job = EventJob(now, createEventClipStream(now));
    jobs.add(job);
    notifyListeners();
    _soundManager.playEvent();

    // Job 완료(스트림 종료) 시점에 리스트에서 제거
    job.subscription.onDone(() {
      jobs.remove(job);
      job.dispose();
      notifyListeners();
      _soundManager.playSaved();
    });
  }

  @override
  void dispose() {
    for (var job in jobs) {
      job.dispose();
    }
    super.dispose();
  }
}
