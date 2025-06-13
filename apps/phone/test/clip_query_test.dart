import 'package:flutter_test/flutter_test.dart';
import 'package:phone/utils/clip_query.dart';
import 'dart:io';
import 'package:xml/xml.dart';

void main() {
  group('ClipQuery.queryFilesByIntervalHeuristic', () {
    // helper: 주어진 name/time으로 ClipInfo 객체 생성
    ClipInfo makeClip(String name, String time) {
      return ClipInfo(name: name, fpath: '/some/path/$name.mp4', time: time);
    }

    test(
      'returns clips whose startTime falls within [queryStart, queryEnd]',
      () {
        final clips = [
          makeClip('clip1', '2025-06-06T10:00:00'),
          makeClip('clip2', '2025-06-06T10:05:00'),
          makeClip('clip3', '2025-06-06T10:10:00'),
          makeClip('clip4', '2025-06-06T10:15:00'),
          makeClip('clip5', '2025-06-06T10:20:00'),
        ];

        final queryStart = DateTime.parse('2025-06-06T10:06:00');
        final queryEnd = DateTime.parse('2025-06-06T10:12:00');

        final result = ClipQuery().queryFilesByIntervalHeuristic(
          queryStart: queryStart,
          queryEnd: queryEnd,
          files: clips,
        );

        // clip2(10:05)와 clip3(10:10)만 반환되어야 한다
        expect(result.map((c) => c.name).toList(), ['clip2', 'clip3']);
      },
    );

    test(
      'when query range is entirely before all clips, returns empty list',
      () {
        final clips = [
          makeClip('clip1', '2025-06-06T11:00:00'),
          makeClip('clip2', '2025-06-06T11:05:00'),
        ];

        final queryStart = DateTime.parse('2025-06-06T10:00:00');
        final queryEnd = DateTime.parse('2025-06-06T10:30:00');

        final result = ClipQuery().queryFilesByIntervalHeuristic(
          queryStart: queryStart,
          queryEnd: queryEnd,
          files: clips,
        );

        expect(result, isEmpty);
      },
    );

    test('when queryStart is after all clip times, returns empty list', () {
      final clips = [
        makeClip('clip1', '2025-06-06T09:00:00'),
        makeClip('clip2', '2025-06-06T09:05:00'),
      ];

      final queryStart = DateTime.parse('2025-06-06T10:00:00');
      final queryEnd = DateTime.parse('2025-06-06T10:30:00');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result, isEmpty);
    });

    test('when queryStart and queryEnd exactly match clip times', () {
      final clips = [
        makeClip('clip1', '2025-06-06T10:00:00'),
        makeClip('clip2', '2025-06-06T10:05:00'),
        makeClip('clip3', '2025-06-06T10:10:00'),
      ];

      final queryStart = DateTime.parse('2025-06-06T10:00:00');
      final queryEnd = DateTime.parse('2025-06-06T10:10:00');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      // 경계값 포함이므로 clip1, clip2, clip3 모두 나와야 한다
      expect(result.map((c) => c.name).toList(), ['clip1', 'clip2']);
    });

    test('when a single clip falls within the range', () {
      final clips = [
        makeClip('clip1', '2025-06-06T08:00:00'),
        makeClip('clip2', '2025-06-06T09:30:00'),
        makeClip('clip3', '2025-06-06T12:00:00'),
      ];

      final queryStart = DateTime.parse('2025-06-06T09:00:00');
      final queryEnd = DateTime.parse('2025-06-06T10:00:00');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result.map((c) => c.name).toList(), ['clip1', 'clip2']);
    });
  });

  group('XML Example Parsing', () {
    test('assets/xml/novatek_list_example.xml 파일을 읽어서 파싱할 수 있어야 한다', () {
      final xmlPath = 'assets/xml/novatek_list_example.xml';
      // 파일이 실제로 존재하는지 먼저 확인
      expect(
        File(xmlPath).existsSync(),
        isTrue,
        reason: '예시 XML 파일이 assets/xml/novatek_list_example.xml 경로에 없습니다.',
      );

      final xmlContent = File(xmlPath).readAsStringSync();
      // xml 패키지를 이용해 파싱 시, 예외가 발생하지 않아야 한다
      final document = XmlDocument.parse(xmlContent);
      // 루트 엘리먼트 이름이 비어 있지 않아야 한다
      expect(document.rootElement.name.local, isNotEmpty);
    });

    // case 1
    test('XML Case 1', () {
      final xmlPath = 'assets/xml/novatek_list_example.xml';
      final xmlString = File(xmlPath).readAsStringSync();
      final document = XmlDocument.parse(xmlString);
      final clips =
          document
              .findAllElements('File')
              .map((e) => ClipInfo.fromXml(e))
              .toList();

      final queryStart = DateTime.parse('2025-06-04T14:34:00');
      final queryEnd = DateTime.parse('2025-06-04T14:44:42');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result.map((c) => c.name).toList(), []);
    });

    // case 2
    test('XML Case 2: one clip in [2025/6/4 14:44:32 – 14:44:52]', () {
      final xmlPath = 'assets/xml/novatek_list_example.xml';
      final xmlString = File(xmlPath).readAsStringSync();
      final document = XmlDocument.parse(xmlString);
      final clips =
          document
              .findAllElements('File')
              .map((e) => ClipInfo.fromXml(e))
              .toList();

      final queryStart = DateTime.parse('2025-06-04T14:44:32');
      final queryEnd = DateTime.parse('2025-06-04T14:44:52');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result.map((c) => c.name).toList(), ['20250604144442_0060.mp4']);
    });

    // case 3
    test('XML Case 3: one clip in [2025/6/4 15:03:42 – 15:03:52]', () {
      final xmlPath = 'assets/xml/novatek_list_example.xml';
      final xmlString = File(xmlPath).readAsStringSync();
      final document = XmlDocument.parse(xmlString);
      final clips =
          document
              .findAllElements('File')
              .map((e) => ClipInfo.fromXml(e))
              .toList();

      final queryStart = DateTime.parse('2025-06-04T15:03:42');
      final queryEnd = DateTime.parse('2025-06-04T15:03:52');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result.map((c) => c.name).toList(), ['20250604150342_0060.mp4']);
    });

    // case 4
    test('XML Case 4: two clips in [2025/6/4 15:04:32 – 15:04:52]', () {
      final xmlPath = 'assets/xml/novatek_list_example.xml';
      final xmlString = File(xmlPath).readAsStringSync();
      final document = XmlDocument.parse(xmlString);
      final clips =
          document
              .findAllElements('File')
              .map((e) => ClipInfo.fromXml(e))
              .toList();

      final queryStart = DateTime.parse('2025-06-04T15:04:32');
      final queryEnd = DateTime.parse('2025-06-04T15:04:52');

      final result = ClipQuery().queryFilesByIntervalHeuristic(
        queryStart: queryStart,
        queryEnd: queryEnd,
        files: clips,
      );

      expect(result.map((c) => c.name).toList(), [
        '20250604150342_0060.mp4',
        '20250604150442_0060.mp4',
      ]);
    });
  });
}
