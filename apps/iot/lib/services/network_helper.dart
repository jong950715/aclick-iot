import 'package:flutter/services.dart';
import 'package:http/http.dart';

class NetworkHelper {
  static const _channel = MethodChannel('com.example.iot/network');

  /// 에페메랄 Wi-Fi 연결
  static Future<bool> connectToSsid({required String ssid, required String password}) async {
    final res = await _channel.invokeMethod<bool>(
        'connectToSsid', {'ssid': ssid, 'passphrase': password});
    return res == true;
  }

  /// HTTP 요청
  static Future<Response> requestOverWifi({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) async {
    final res = await _channel.invokeMethod<Map>(
        'requestOverWifi', {
      'method': method,
      'url': url,
      'headers': headers,
      'body': body,
    });
    return Response(res?['body'] as String, res?['code'] as int);
    // return {
    //   'success': res?['success'] as bool,
    //   'code': res?['code'] as int,
    //   'body': res?['body'] as String?,
    // };
  }

  /// 원격에서 보내는 onResponse 이벤트(필요 시 사용)
  static void setOnResponseListener(void Function(bool, int, String?) cb) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onResponse') {
        final args = call.arguments as Map;
        cb(args['success'], args['code'], args['body']);
      }
    });
  }
}
