package com.example.ephemeral_wifi

import com.example.ephemeral_wifi.EphemeralWifiManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** EphemeralWifiPlugin */
class EphemeralWifiPlugin : FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var wifiMgr: EphemeralWifiManager
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ephemeral_wifi")
        channel.setMethodCallHandler(this)
        wifiMgr = EphemeralWifiManager(flutterPluginBinding.applicationContext)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "connectToSsid" -> {
                val ssid = call.argument<String>("ssid")!!
                val pass = call.argument<String>("passphrase")!!
                wifiMgr.connectToSsid(ssid, pass, object : EphemeralWifiManager.Callback {
                    override fun onFileDownloaded(success: Boolean, filePath: String?) {}
                    override fun onConnected() {
                        result.success(true)
                    }

                    override fun onResponse(success: Boolean, code: Int, body: String?) {
                        channel.invokeMethod(
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
                val url = call.argument<String>("url")!!
                val headers = call.argument<Map<String, String>>("headers")
                val body = call.argument<String>("body")
                wifiMgr.requestOverWifi(
                    method,
                    url,
                    headers,
                    body,
                    object : EphemeralWifiManager.Callback {
                        override fun onFileDownloaded(success: Boolean, filePath: String?) {}
                        override fun onConnected() { /* not used */
                        }

                        override fun onResponse(success: Boolean, code: Int, body: String?) {
                            result.success(
                                mapOf(
                                    "success" to success,
                                    "code" to code,
                                    "body" to body
                                )
                            )
                        }

                        override fun onError(error: String) {
                            result.error("HTTP_ERROR", error, null)
                        }
                    })
            }

            "uploadFileOverWifi" -> {
                val url = call.argument<String>("url")!!
                val filePath = call.argument<String>("filePath")!!
                val formField = call.argument<String>("formField") ?: "file"
                val headers = call.argument<Map<String, String>>("headers")
                wifiMgr.uploadFileOverWifi(
                    url,
                    filePath,
                    formField,
                    headers,
                    object : EphemeralWifiManager.Callback {
                        override fun onFileDownloaded(success: Boolean, filePath: String?) {}
                        override fun onConnected() { /* not used */
                        }

                        override fun onResponse(success: Boolean, code: Int, body: String?) {
                            result.success(
                                mapOf(
                                    "success" to success,
                                    "code" to code,
                                    "body" to body
                                )
                            )
                        }

                        override fun onError(error: String) {
                            result.error("UPLOAD_ERROR", error, null)
                        }
                    })
            }

            "downloadFileOverWifi" -> {
                val url = call.argument<String>("url")!!
                val destFilePath = call.argument<String>("destFilePath")!!
                wifiMgr.downloadFileOverWifi(url, destFilePath, object : EphemeralWifiManager.Callback {
                    override fun onConnected() {
                        // 이미 연결된 네트워크 채널을 사용하므로 별도 처리 불필요
                    }

                    override fun onFileDownloaded(success: Boolean, filePath: String?) {
                        result.success(
                            mapOf(
                                "success" to success,
                                "filePath" to filePath
                            )
                        )
                    }

                    override fun onResponse(success: Boolean, code: Int, body: String?) {
                        // downloadFileOverWifi 에서는 사용되지 않음
                    }

                    override fun onError(error: String) {
                        result.error("DOWNLOAD_ERROR", error, null)
                    }
                })
            }

            "dispose" -> {
                wifiMgr.dispose()  // 5) dispose 메서드 추가
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
