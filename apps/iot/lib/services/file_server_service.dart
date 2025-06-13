import 'dart:async';
import 'dart:io';
import 'package:iot/repositories/app_logger.dart';
import 'package:iot/utils/file_path_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart' as xml;

part 'file_server_service.g.dart';

class ClipInfo {
  final String name;
  final String fpath;
  final String time;

  ClipInfo({required this.name, required this.fpath, required this.time});
}

@Riverpod(keepAlive: true)
class FileServerService extends _$FileServerService {
  HttpServer? _server;
  AppLogger get _logger => ref.watch(appLoggerProvider.notifier);
  final StreamController<String> _fileTransferred = StreamController();
  Stream<String> get fileTransferredStream => _fileTransferred.stream.asBroadcastStream();


  @override
  void build() {
  }

  Future<void> startServer() async {
    _logger.logInfo('파일 서버 시작 시도');

    /// 본격 서버 설정
    _logger.logInfo('요청 로깅 미들웨어 추가');
    final handler = Pipeline().addMiddleware(logRequests()).addHandler((
        Request req,
        ) async {
      _logger.logDebug('수신된 요청: ${req.method} ${req.url}');

      final path = req.url.path; // Novatek/20250604145442_0060.mp4

      /// GET 이외의 응답
      if (req.method != 'GET') return Response(405);

      if (req.url.queryParameters['cmd'] == '3015') {
        return _listNovatekVideosAsXml();
      }

      /// static file 요청들 처리
      return await _moviesFileHandler(req);
    });
    
    _logger.logInfo('서버 객체 생성 및 시작 - 포트: 61428');
    _server = await io.serve(handler, InternetAddress.anyIPv4, 61428);
    _logger.logInfo('파일 서버 시작 완료');
  }

  Future<void> stopServer() async {
    _logger.logInfo('파일 서버 중지 시도');
    if (_server == null) {
      _logger.logWarning('중지할 서버 인스턴스가 없음');
      return;
    }
    _server?.close();
    _logger.logInfo('파일 서버 중지 완료');
  }

  Future<Response> _aclickEventFileHandler(Request request) async {
    return createStaticHandler(
      '${await FilePathUtils.getVideoDirectoryPath()}/AclickEvents',
      serveFilesOutsidePath: true, // 경로에 ../ 가 있을 때도 허용하려면 true
      defaultDocument: null, // 디렉터리 요청 시 기본 문서턴 안함
    )(request);
  }


  Future<Response> _moviesFileHandler(Request request) async {
    final res = createStaticHandler(
      '${await FilePathUtils.getVideoDirectoryPath()}',
      serveFilesOutsidePath: true, // 경로에 ../ 가 있을 때도 허용하려면 true
      defaultDocument: null, // 디렉터리 요청 시 기본 문서턴 안함
    )(request);

    final filename = request.url.pathSegments.isNotEmpty ? request.url
        .pathSegments.last : null;
    if (filename == null) return res;

    _logger.logInfo('파일 전송 성공: $filename');
    _fileTransferred.add(filename);

    return res;
  }


  Future<Response> _listNovatekVideosAsXml() async {
    final basePath = await FilePathUtils.getVideoDirectoryPath();
    final pathOnBase = 'Aclick';
    final directory = Directory('$basePath/$pathOnBase');

    if (!await directory.exists()) {
      return Response.internalServerError(
        body: '<error>Directory not found</error>',
        headers: {'content-type': 'application/xml; charset=UTF-8'},
      );
    }

    // 파일 정보를 담을 간단한 Dart 객체


    final List<ClipInfo> filesInfo = [];

    await for (final entity in directory.list(recursive: false)) {
      if (entity is File) {

        final name = entity.uri.pathSegments.last;
        final lower = name.toLowerCase();
        if (!(lower.endsWith('.mov') || lower.endsWith('.mp4'))) {
          continue;
        }
        if (lower.startsWith('.pending')){
          continue;
        }

        // final s = '20250604144442';
        final yyyy = int.parse(name.substring(0, 4)); // 2025
        final MM = int.parse(name.substring(4, 6)); // 06
        final dd = int.parse(name.substring(6, 8)); // 04
        final HH = int.parse(name.substring(9, 11)); // 14
        final mm = int.parse(name.substring(11, 13)); // 44
        final ss = int.parse(name.substring(13, 15)); // 42
        final timeString = DateTime(yyyy, MM, dd, HH, mm, ss).toIso8601String();

        // Windows 경로 구분자가 필요하다면 replaceAll 사용
        final fpath = entity.path.replaceAll('/', '\\');

        filesInfo.add(
            ClipInfo(name: name, fpath: '$pathOnBase/$name', time: timeString));
      }
    }

    // xml 패키지로 안전하게 직렬화
    final builder = xml.XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('LIST', nest: () {
      for (final file in filesInfo) {
        builder.element('ALLFile', nest: () {
          builder.element('File', nest: () {
            builder.element('NAME', nest: file.name);
            builder.element('FPATH', nest: file.fpath);
            builder.element('TIME', nest: file.time);
          });
        });
      }
    });

    final document = builder.buildDocument();
    final xmlString = document.toXmlString(pretty: true, indent: '  ');

    return Response.ok(
      xmlString,
      headers: {'content-type': 'application/xml; charset=UTF-8'},
    );
  }
}
