import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:xml/xml.dart';
import 'package:flutter/services.dart' show rootBundle;

// ClipInfo에 factory constructor 추가
class ClipInfo {
  final String name;
  final String fpath;
  final String time;

  ClipInfo({required this.name, required this.fpath, required this.time});

  DateTime get startTime => DateTime.parse(time);

  // 예시 XML 구조:
  // <Clip>
  //   <Name>20250604144442_0060.mp4</Name>
  //   <Fpath>/path/to/20250604144442_0060.mp4</Fpath>
  //   <Time>2025-06-04T14:44:42</Time>
  // </Clip>
  factory ClipInfo.fromXml(XmlElement element) {
    final nameElem = element.findElements('NAME').single;
    final fpathElem = element.findElements('FPATH').single;
    final timeElem = element.findElements('TIME').single;

    return ClipInfo(
      name: nameElem.innerText ?? '',
      fpath: fpathElem.innerText ?? '',
      time: timeElem.innerText ?? '',
    );
  }
}
final clipQueryProvider = NotifierProvider<ClipQuery, void>(() => ClipQuery());
class ClipQuery extends Notifier<void> {
  List<ClipInfo> files = [];
  @override
  void build() {
    return;
  }

  Future<List<ClipInfo>> _fetchClipInfo() async {
    // 테스트를 위해서 로컬 파일을 불러오는 코드
    final xmlPath = 'assets/xml/novatek_list_example.xml';
    final xmlString = await rootBundle.loadString(xmlPath);
    final document = XmlDocument.parse(xmlString);
    final clips =
    document
        .findAllElements('File')
        .map((e) => ClipInfo.fromXml(e))
        .toList();
    return clips;
  }

  Future<List<ClipInfo>> getClipInfos({
    required DateTime queryStart,
    required DateTime queryEnd,
  }) async {
    if (files.isEmpty) {
      files = await _fetchClipInfo();
    }
    return queryFilesByIntervalHeuristic(files: files, queryStart: queryStart, queryEnd: queryEnd);
  }

  List<ClipInfo> queryFilesByIntervalHeuristic({
    required List<ClipInfo> files,
    required DateTime queryStart,
    required DateTime queryEnd,
  }) {
    if (files.isEmpty) return [];

    // 1) 시작 시각 기준 오름차순 정렬
    files.sort((a, b) => a.time.compareTo(b.time));

    queryStart =
        (queryStart.isBefore(files.first.startTime))
            ? files.first.startTime
            : queryStart;
    // queryEnd = (queryEnd.isAfter(files.last.endTime)) ? files.last.startTime : queryEnd;
    // end도 clamp 하면 깔끔할텐데 없으니까, 그냥 일부 rare case 손절
    if (files.last.startTime.isBefore(queryStart)) return [];

    // 2) lowerBound을 이용해 첫 번째 파일 인덱스 찾기
    //    lowerBound은 files[i].startTime >= queryStart인 i를 반환
    final idx = files.lowerBound(
      ClipInfo(time: queryStart.toString(), name: '', fpath: ''),
      (a, b) => a.startTime.compareTo(b.startTime),
    );

    int startIdx;
    if (files[idx].startTime.isAtSameMomentAs(queryStart)) {
      startIdx = idx;
    } else {
      startIdx = idx - 1;
    }

    // 4) startIdx부터 queryEnd보다 작은 동안 순차 탐색
    final matches = <ClipInfo>[];
    for (var i = startIdx; i < files.length; i++) {
      if (!files[i].startTime.isBefore(queryEnd)) break;
      matches.add(files[i]);
    }
    return matches;
  }
}
