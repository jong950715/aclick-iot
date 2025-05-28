// lib/ephemeral_wifi_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class EphemeralWifiManager {
  /// MethodChannel 이름은 네이티브(Android/iOS) 쪽과 반드시 일치시켜야 합니다.
  static const MethodChannel _methodChannel =
  MethodChannel('ephemeral_wifi');

  EphemeralWifiManager._();
  static final EphemeralWifiManager instance = EphemeralWifiManager._();

  /// SSID에 연결
  /// returns true if connected successfully
  Future<bool> connectToSsid({
    required String ssid,
    required String passphrase,
  }) async {
    final bool? ok = await _methodChannel.invokeMethod<bool>(
      'connectToSsid',
      {
        'ssid': ssid,
        'passphrase': passphrase,
      },
    );
    return ok == true;
  }

  /// Wi-Fi 연결 후 HTTP 요청 (GET, POST, etc.)
  Future<EphemeralWifiHttpResponse> requestOverWifi({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) async {
    final Map<dynamic, dynamic> result =
    await _methodChannel.invokeMethod(
      'requestOverWifi',
      <String, dynamic>{
        'method': method,
        'url': url,
        if (headers != null) 'headers': headers,
        if (body != null) 'body': body,
      },
    );
    return EphemeralWifiHttpResponse.fromMap(
        Map<String, dynamic>.from(result));
  }

  /// Wi-Fi 연결 후 파일 업로드
  Future<EphemeralWifiHttpResponse> uploadFileOverWifi({
    required String url,
    required String filePath,
    String formField = 'file',
    Map<String, String>? headers,
  }) async {
    final Map<dynamic, dynamic> result =
    await _methodChannel.invokeMethod(
      'uploadFileOverWifi',
      <String, dynamic>{
        'url': url,
        'filePath': filePath,
        'formField': formField,
        if (headers != null) 'headers': headers,
      },
    );
    return EphemeralWifiHttpResponse.fromMap(
        Map<String, dynamic>.from(result));
  }

  /// 파일 다운로드
  Future<bool> downloadFileOverWifi({
    required String url,
    required String destFilePath,
  }) async {
    final Map<dynamic, dynamic> result =
    await _methodChannel.invokeMethod(
      'downloadFileOverWifi',
      <String, dynamic>{
        'url': url,
        'destFilePath': destFilePath,
      },
    );
    return result['success'] as bool;
  }

  /// 내부 리소스 정리
  Future<void> dispose() async {
    await _methodChannel.invokeMethod('dispose');
  }
}

/// HTTP 요청·업로드 응답 모델
@immutable
class EphemeralWifiHttpResponse {
  final bool success;
  final int code;
  final String? body;

  const EphemeralWifiHttpResponse({
    required this.success,
    required this.code,
    this.body,
  });

  factory EphemeralWifiHttpResponse.fromMap(Map<String, dynamic> m) {
    return EphemeralWifiHttpResponse(
      success: m['success'] as bool? ?? false,
      code: m['code'] as int? ?? 0,
      body: m['body'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'success': success,
    'code': code,
    'body': body,
  };
}
