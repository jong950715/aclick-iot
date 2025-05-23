import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// HTTP 서버 서비스 클래스
/// WiFi 연결 후 HTTP 서버를 시작하여 Phone 앱과의 데이터 교환을 처리합니다.
class HttpServerService {
  HttpServer? _server;
  bool _isRunning = false;
  final int _defaultPort = 8080;
  
  /// 현재 서버 상태
  bool get isRunning => _isRunning;
  
  /// 현재 포트 (서버가 실행 중이 아니면 null)
  int? get currentPort => _isRunning ? _server?.port : null;

  /// HTTP 서버 시작
  /// [port] 서버 포트 (기본값: 8080)
  /// [onLog] 로그 콜백 함수
  Future<bool> startServer({
    int? port,
    Function(String message)? onLog,
  }) async {
    if (_isRunning) {
      onLog?.call('서버가 이미 실행 중입니다 (포트: ${_server?.port})');
      return true;
    }

    try {
      // 핸들러 설정
      final handler = const shelf.Pipeline()
          .addMiddleware(shelf.logRequests())
          .addHandler(_handleRequest);
      
      // 서버 시작
      _server = await shelf_io.serve(
        handler, 
        InternetAddress.anyIPv4, 
        port ?? _defaultPort,
      );
      
      _isRunning = true;
      
      onLog?.call('HTTP 서버가 시작되었습니다 - http://${_server?.address.host}:${_server?.port}');
      return true;
    } catch (e) {
      onLog?.call('HTTP 서버 시작 오류: $e');
      return false;
    }
  }

  /// HTTP 서버 중지
  Future<bool> stopServer({Function(String message)? onLog}) async {
    if (!_isRunning || _server == null) {
      onLog?.call('서버가 실행 중이 아닙니다');
      return true;
    }

    try {
      await _server?.close(force: true);
      _server = null;
      _isRunning = false;
      onLog?.call('HTTP 서버가 중지되었습니다');
      return true;
    } catch (e) {
      onLog?.call('HTTP 서버 중지 오류: $e');
      return false;
    }
  }

  /// 요청 핸들러
  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    // URL 경로 처리
    final path = request.url.path;
    
    // 메서드 처리
    final method = request.method;
    
    if (kDebugMode) {
      print('요청 수신: $method $path');
    }
    
    // 핑퐁 엔드포인트
    if (path == 'ping' || path.isEmpty) {
      return shelf.Response.ok(
        '{"status": "success", "message": "pong", "timestamp": "${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    // 상태 확인 엔드포인트
    if (path == 'status') {
      return shelf.Response.ok(
        '{"status": "success", "server": "running", "timestamp": "${DateTime.now().toIso8601String()}"}',
        headers: {'Content-Type': 'application/json'},
      );
    }
    
    // 데이터 수신 엔드포인트 (POST 요청)
    if (path == 'data' && method == 'POST') {
      try {
        final payload = await request.readAsString();
        // 여기에서 데이터 처리 로직을 구현합니다
        
        return shelf.Response.ok(
          '{"status": "success", "message": "Data received", "size": ${payload.length}}',
          headers: {'Content-Type': 'application/json'},
        );
      } catch (e) {
        return shelf.Response.internalServerError(
          body: '{"status": "error", "message": "Failed to process data: $e"}',
          headers: {'Content-Type': 'application/json'},
        );
      }
    }
    
    // 404 응답
    return shelf.Response.notFound(
      '{"status": "error", "message": "Not found"}',
      headers: {'Content-Type': 'application/json'},
    );
  }
}
