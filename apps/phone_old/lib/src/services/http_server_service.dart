// bin/server.dart
import 'dart:convert';
import 'dart:io';
import 'package:media_scanner/media_scanner.dart';
import 'package:phone/src/utils/file_path_utils.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

class HttpServerService {
  final InternetAddress address;
  final int port;
  late final Router _router;
  int _pingCount = 0;  // ping 요청 수 카운트
  bool isRunning = false;

  void Function(dynamic message) _onLog = (_){};

  HttpServerService({
    InternetAddress? address,
    this.port = 8080,
  }) : address = address ?? InternetAddress.anyIPv4 {
    _router = _buildRouter();
  }

  /// 서버 실행 진입점
  Future<bool> startServer({void Function(dynamic message)? onLog}) async {
    _onLog = onLog ?? _onLog;
    final handler = Pipeline().addMiddleware(logRequests()).addHandler(_router);

    final server = await serve(handler, address, port);
    _onLog('🚀 Server listening on ${server.address.host}:${server.port}');

    isRunning = true;
    return true;
  }

  /// 라우터·엔드포인트 구성
  Router _buildRouter() {
    final router = Router();
    router.get('/ping', _pingHandler);
    router.post('/upload', _uploadHandler);
    return router;
  }

  /// stop
  Future<bool> stopServer() async {
    // TODO stop!
    return true;
  }

  /// 헬스체크용
  Response _pingHandler(Request req) {
    _pingCount++;
    final timestamp = DateTime.now().toIso8601String();
    final body = jsonEncode({
      'status': 'success',
      'message': 'pong',
      'count': _pingCount,
      'timestamp': timestamp,
    });

    _onLog(body.toString());
    return Response.ok(
      body,
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<Response> _uploadHandler(Request request) async {
    final multipart = request.multipart();
    if (multipart == null) {
      return Response(400, body: 'Expected multipart/form-data');
    }

    await for (final part in multipart.parts) {
      final cd = part.headers['content-disposition'] ?? '';
      final m = RegExp(r'filename="([^"]*)"').firstMatch(cd);
      if (m == null) continue;


      final filename = m.group(1)!;
      final path = '${await FilePathUtils.getVideoDirectoryPath()}/$filename';
      final file = File(path);
      await part.pipe(file.openWrite());
      await MediaScanner.loadMedia(path: path);
    }

    return Response(201, body: 'Upload OK');
  }
}
