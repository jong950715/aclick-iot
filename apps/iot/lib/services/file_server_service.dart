import 'dart:io';
import 'package:iot/repositories/app_logger.dart';
import 'package:iot/utils/file_path_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'file_server_service.g.dart';

@Riverpod(keepAlive: true)
class FileServerService extends _$FileServerService {
  HttpServer? _server;
  AppLogger get _logger => ref.watch(appLoggerProvider.notifier);


  @override
  void build() {
  }

  Future<void> startServer() async {
    _logger.logInfo('파일 서버 시작 시도');
    final filesDir = '${await FilePathUtils.getVideoDirectoryPath()}Events';
    _logger.logInfo('이벤트 클립 디렉토리 경로: $filesDir');
    
    _logger.logInfo('정적 파일 핸들러 생성');
    final staticHandler = createStaticHandler(
      filesDir,
      serveFilesOutsidePath: true, // 경로에 ../ 가 있을 때도 허용하려면 true
      defaultDocument: null, // 디렉터리 요청 시 기본 문서 반환 안 함
    );
    
    _logger.logInfo('요청 로깅 미들웨어 추가');
    final handler = Pipeline().addMiddleware(logRequests()).addHandler((
        Request req,
        ) {
      _logger.logDebug('수신된 요청: ${req.method} ${req.url}');
      if (req.method != 'GET') {
        _logger.logWarning('GET 이외의 메소드 발견: ${req.method}, 405 응답');
        return Response(405);
      }
      return staticHandler(req);
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
}
