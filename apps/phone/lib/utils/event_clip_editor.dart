import 'package:cross_file/cross_file.dart';
import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phone/services/network_service.dart';
import 'package:phone/utils/clip_query.dart';
import 'package:async/async.dart';
import 'package:phone/utils/file_path_utils.dart';

final eventClipEditorProvider = NotifierProvider<EventClipEditor, void>(
  () => EventClipEditor(),
);

class EventClipEditor extends Notifier<void> {
  ClipQuery get _query => ref.read(clipQueryProvider.notifier);

  NetworkService get _network => ref.read(networkServiceProvider.notifier);

  @override
  void build() {}

  Future<List<String>> fetchEventClips(List<ClipInfo> clipInfos) async {
    return await Future.wait(clipInfos.map((e) => _network.downloadClip(e.fpath),));
    // 1) clip 개수와 같은 길이의 결과 리스트를 미리 준비 (초깃값은 null)
    final results = List<String?>.filled(clipInfos.length, null);

    // 2) 인덱스를 공유할 변수
    var currentIndex = 0;

    // 3) 인덱스 반환 함수 (더 이상 남은 클립이 없으면 -1 반환)
    int getNextIndex() {
      if (currentIndex >= clipInfos.length) return -1;
      return currentIndex++;
    }

    // 4) 워커(Worker) 함수: 자기 인덱스를 꺼내와서 작업하고, 그 결과를 results[idx]에 저장
    Future<void> worker() async {
      while (true) {
        final idx = getNextIndex();
        if (idx == -1) return; // 더 처리할 게 없으면 종료

        // 다운로드하고, 리턴값을 받아서 resu
        // lts[idx]에 저장
        final res = await _network.downloadClip(clipInfos[idx].fpath);
        results[idx] = res;
      }
    }

    // 5) 워커 3개를 동시에 실행
    await Future.wait([
      // worker(),
      worker(),
      worker(),
    ]);

    // 6) 결과 리스트(null 제거)는 모두 채워졌으므로, null이 아님을 보장하며
    return results.cast<String>();
  }

  Future<XFile> makeEventClip(int timestampSeconds) async {
    DateTime from = DateTime.fromMillisecondsSinceEpoch(
      timestampSeconds * 1000,
    );
    Duration duration = Duration(seconds: 40);

    final clipInfos = await _query.getClipInfos(
      queryStart: from,
      queryEnd: from.add(duration),
    );
    // final clips = await fetchEventClips(clipInfos);

    final clips = [
      '/storage/emulated/0/Movies/Aclick/Novatek/20250604144842_0060.mp4',
      '/storage/emulated/0/Movies/Aclick/Novatek/20250604144942_0060.mp4',
    ];

    final startTimeMs = from.difference(clipInfos.first.startTime).inMilliseconds;



    final editor = VideoEditorBuilder(videoPath: clips.first);
    editor
        .merge(otherVideoPaths: clips.sublist(1))
        .trim(startTimeMs: startTimeMs, endTimeMs: startTimeMs + 40 * 1000);
    final outputPath = await editor.export(
      outputPath:
          '${await FilePathUtils.getVideoDirectoryPath()}/Aclick/event_${timestampSeconds}.mp4',
    );
    print('outputPath: $outputPath');
    return XFile(outputPath!);
  }
}
