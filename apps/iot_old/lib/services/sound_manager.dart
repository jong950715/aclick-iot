import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final soundManagerProvider = Provider((_) => SoundManager());

class SoundManager {
  static final SoundManager _instance = SoundManager._internal();

  factory SoundManager() => _instance;

  final AudioPlayer _player = AudioPlayer();

  SoundManager._internal();

  /// 사운드 파일을 재생합니다.
  Future<void> playEvent() async {
    // assets 폴더의 WAV 파일을 재생
    await _player.play(AssetSource('sounds/event_sound.wav'));
  }

  Future<void> playSaved() async {
    // assets 폴더의 WAV 파일을 재생
    await _player.play(AssetSource('sounds/saved_sound.wav'));
  }

  Future<void> playError() async =>
      await _player.play(AssetSource('sounds/error_sound.wav'));

  /// 리소스 해제 (앱 종료 시 호출 권장)
  Future<void> dispose() async {
    await _player.dispose();
  }
}
