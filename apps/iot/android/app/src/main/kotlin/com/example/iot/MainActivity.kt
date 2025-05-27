package com.example.iot

import android.os.Bundle
import com.example.my_volume_app.VolumeKeyActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: VolumeKeyActivity() {
    private val NETWORK_CHANNEL = "com.example.iot/network"

    private lateinit var wifiMgr: EphemeralWifiManager
    private lateinit var videoMethodChannel: VideoMethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // (2) VideoMethodChannel 플러그인 수동 추가
        flutterEngine
            .plugins
            .add(VideoMethodChannel())
        
        // Wi-Fi 관리자 초기화
        wifiMgr = EphemeralWifiManager(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NETWORK_CHANNEL)
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
                                MethodChannel(
                                    flutterEngine.dartExecutor.binaryMessenger,
                                    NETWORK_CHANNEL
                                ).invokeMethod(
                                    "onResponse",
                                    mapOf(
                                        "success" to success,
                                        "code" to code,
                                        "body" to body
                                    )
                                )
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
                            override fun onConnected() { /* not used */ }
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

                    "uploadFileOverWifi" -> {
                        val url       = call.argument<String>("url")!!
                        val filePath  = call.argument<String>("filePath")!!
                        val formField = call.argument<String>("formField") ?: "file"
                        val headers   = call.argument<Map<String, String>>("headers")
                        wifiMgr.uploadFileOverWifi(url, filePath, formField, headers, object: EphemeralWifiManager.Callback {
                            override fun onConnected() { /* not used */ }
                            override fun onResponse(success: Boolean, code: Int, body: String?) {
                                result.success(mapOf(
                                    "success" to success,
                                    "code"    to code,
                                    "body"    to body
                                ))
                            }
                            override fun onError(error: String) {
                                result.error("UPLOAD_ERROR", error, null)
                            }
                        })
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
