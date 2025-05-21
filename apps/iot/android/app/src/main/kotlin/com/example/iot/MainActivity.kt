package com.example.iot

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.iot/network"
    private lateinit var wifiMgr: EphemeralWifiManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wifiMgr = EphemeralWifiManager(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connectToSsid" -> {
                        val ssid = call.argument<String>("ssid")!!
                        val pass = call.argument<String>("passphrase")!!
                        wifiMgr.connectToSsid(ssid, pass, object: EphemeralWifiManager.Callback {
                            override fun onConnected() {
                                result.success(true)
                            }
                            override fun onResponse(success: Boolean, code: Int, body: String?) {
                                // HTTP 응답은 별도 채널/콜백으로 보내도 되고,
                                // 여기선 Dart에서 바로 받도록 MethodChannel.invokeMethod 써도 됩니다.
                                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                    .invokeMethod("onResponse", mapOf(
                                        "success" to success,
                                        "code" to code,
                                        "body" to body
                                    ))
                            }
                            override fun onError(error: String) {
                                result.error("NETWORK_ERROR", error, null)
                            }
                        })
                    }
                    "requestOverWifi" -> {
                        val method = call.argument<String>("method")!!
                        val url    = call.argument<String>("url")!!
                        val headers= call.argument<Map<String, String>>("headers")
                        val body   = call.argument<String>("body")
                        wifiMgr.requestOverWifi(method, url, headers, body, object: EphemeralWifiManager.Callback {
                            override fun onConnected() { /* not used here */ }
                            override fun onResponse(success: Boolean, code: Int, body: String?) {
                                result.success(mapOf(
                                    "success" to success,
                                    "code"    to code,
                                    "body"    to body
                                ))
                            }
                            override fun onError(error: String) {
                                result.error("HTTP_ERROR", error, null)
                            }
                        })
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
