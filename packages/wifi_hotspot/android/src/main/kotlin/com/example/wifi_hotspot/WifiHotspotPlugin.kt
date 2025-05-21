package com.example.wifi_hotspot

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleOwner
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.net.Inet4Address
import java.net.NetworkInterface

/** WifiHotspotPlugin */
class WifiHotspotPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
  private val TAG = "WifiHotspotPlugin"
  private val CHANNEL = "com.example.wifi/hotspot"
  private val HTTP_SERVER_PORT = 8080 // 기본 HTTP 서버 포트
  
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
  private var activity: ActivityPluginBinding? = null
  private val mainScope = CoroutineScope(Dispatchers.Main)
  private var connectivityManager: ConnectivityManager? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
    connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "startHotspot" -> startLocalOnlyHotspot(result)
      "stopHotspot" -> {
        stopHotspot()
        result.success("Hotspot stopped")
      }
      "isHotspotActive" -> {
        result.success(hotspotReservation != null)
      }
      "connectToWifi" -> {
        val ssid = call.argument<String>("ssid")
        val password = call.argument<String>("password")
        
        if (ssid == null || password == null) {
          result.error("INVALID_ARGUMENTS", "SSID and password are required", null)
          return
        }
        
        connectToWifi(ssid, password, result)
      }
      else -> {
        result.notImplemented()
      }
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    stopHotspot()
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding
  }

  override fun onDetachedFromActivity() {
    stopHotspot()
    activity = null
  }

  private fun waitForIp(maxTries: Int = 10, delayMillis: Long = 500): String {
    repeat(maxTries) { attempt ->
      val ip = getLocalIpAddress()
      if (ip != "Unknown IP") return ip
      Thread.sleep(delayMillis)
    }
    return "Unknown IP"
  }

  private fun startLocalOnlyHotspot(@NonNull result: Result) {
    // Only supports Android 12+ (API 31+)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      // 이미 활성화된 핫스팟이 있는 경우 재사용
      if (hotspotReservation != null) {
        Log.d(TAG, "Reusing existing hotspot reservation")
        // 기존 핫스팟 정보 제공
        val reservation = hotspotReservation!!
        val config = reservation.softApConfiguration
        val ssid = config?.ssid ?: "Unknown SSID"
        val passphrase = config?.passphrase ?: "Unknown Key"
        
        mainScope.launch(Dispatchers.IO) {
          val ipAddress = waitForIp()
          val response = HashMap<String, Any>()
          response["ssid"] = ssid
          response["password"] = passphrase
          response["ipAddress"] = ipAddress
          response["port"] = HTTP_SERVER_PORT
          withContext(Dispatchers.Main) {
            result.success(response)
          }
        }
        return
      }
      
      // 새로운 핫스팟 시작
      try {
        val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
        wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
          override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
            super.onStarted(reservation)
            hotspotReservation = reservation
            
            val config = reservation.softApConfiguration
            val ssid = config?.ssid ?: "Unknown SSID"
            val passphrase = config?.passphrase ?: "Unknown Key"
            val bssid = config?.bssid?.toString() ?: "Unknown BSSID"
            
            Log.d(TAG, "Hotspot started with SSID: $ssid")
            
            mainScope.launch(Dispatchers.IO) {
              val ipAddress = waitForIp()
              val response = HashMap<String, Any>()
              response["ssid"] = ssid
              response["bssid"] = bssid
              response["password"] = passphrase
              response["ipAddress"] = ipAddress
              response["port"] = HTTP_SERVER_PORT
              withContext(Dispatchers.Main) {
                result.success(response)
              }
            }
          }

          override fun onFailed(reason: Int) {
            super.onFailed(reason)
            Log.e(TAG, "Failed to start hotspot with reason code: $reason")
            result.error("HOTSPOT_FAILED", "Failed with reason code $reason", null)
          }
        }, null)
      } catch (e: IllegalStateException) {
        // 동시에 여러 요청이 발생할 경우의 예외 처리
        Log.e(TAG, "IllegalStateException: ${e.message}")
        result.error("HOTSPOT_FAILED", "Already has an active request: ${e.message}", null)
      } catch (e: Exception) {
        Log.e(TAG, "Exception starting hotspot: ${e.message}")
        result.error("HOTSPOT_FAILED", "Failed to start hotspot: ${e.message}", null)
      }
    } else {
      result.error("UNSUPPORTED", "Android 12 (API 31) or higher is required", null)
    }
  }

  private fun stopHotspot() {
    hotspotReservation?.close()
    hotspotReservation = null
    Log.d(TAG, "Hotspot stopped")
  }

  private fun getLocalIpAddress(): String {
    return try {
      val interfaces = NetworkInterface.getNetworkInterfaces()
      interfaces?.asSequence()?.forEach { networkInterface ->
        if (networkInterface.name == "swlan0") {
          networkInterface.inetAddresses?.asSequence()?.forEach { address ->
            if (!address.isLoopbackAddress && address is Inet4Address) {
              return address.hostAddress ?: "Unknown IP"
            }
          }
        }
      }
      
      // If swlan0 wasn't found or didn't have a valid IP, try with all interfaces
      NetworkInterface.getNetworkInterfaces().toList().forEach { networkInterface ->
        if (networkInterface.isUp && !networkInterface.isLoopback) {
          networkInterface.inetAddresses.toList().forEach { address ->
            if (!address.isLoopbackAddress && address is Inet4Address) {
              return address.hostAddress ?: "Unknown IP"
            }
          }
        }
      }
      
      "Unknown IP"
    } catch (e: Exception) {
      Log.e(TAG, "Error getting IP address", e)
      "Unknown IP"
    }
  }
  
  private fun connectToWifi(ssid: String, password: String, result: Result) {
    // Wi-Fi 연결 기능은 Android 10(API 29) 이상에서만 지원됩니다.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      try {
        // Wi-Fi 네트워크 명세 생성
        val spec = WifiNetworkSpecifier.Builder()
          .setSsid(ssid)
          .setWpa2Passphrase(password)
          .build()

        // 네트워크 요청 생성
        val request = NetworkRequest.Builder()
          .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
          .setNetworkSpecifier(spec)
          .build()
          
        Log.d(TAG, "Initiating connection to Wi-Fi network: $ssid")
          
        // 연결 요청 콜백
        val callback = object : ConnectivityManager.NetworkCallback() {
          override fun onAvailable(network: android.net.Network) {
            super.onAvailable(network)
            Log.d(TAG, "Network is available")
            mainScope.launch(Dispatchers.Main) {
              result.success(true)
            }
          }
          
          override fun onUnavailable() {
            super.onUnavailable()
            Log.d(TAG, "Network is unavailable")
            mainScope.launch(Dispatchers.Main) {
              result.success(false)
            }
          }
        }
        
        // 이전 요청 취소 (예외 발생 가능성이 있어 try-catch로 감싸야 함)
        try {
          connectivityManager?.unregisterNetworkCallback(callback)
        } catch (e: IllegalArgumentException) {
          // 등록되지 않은 콜백을 해제하려고 할 때 발생하는 예외 무시
        }
        
        // 새 연결 요청
        connectivityManager?.requestNetwork(request, callback)
        
        // 결과는 콜백에서 처리하기 때문에 여기서는 반환하지 않습니다.
      } catch (e: Exception) {
        Log.e(TAG, "Error connecting to Wi-Fi: ${e.message}")
        result.error("CONNECTION_ERROR", "Failed to connect to Wi-Fi: ${e.message}", null)
      }
    } else {
      // Android 10 미만에서는 지원하지 않음
      result.error("UNSUPPORTED_VERSION", "Wi-Fi connection requires Android 10 or higher", null)
    }
  }
}
