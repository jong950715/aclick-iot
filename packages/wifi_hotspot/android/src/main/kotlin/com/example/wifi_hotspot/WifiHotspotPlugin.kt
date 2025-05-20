package com.example.wifi_hotspot

import android.content.Context
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
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
  
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var hotspotReservation: WifiManager.LocalOnlyHotspotReservation? = null
  private var activity: ActivityPluginBinding? = null
  private val mainScope = CoroutineScope(Dispatchers.Main)

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, CHANNEL)
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
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
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as WifiManager
      wifiManager.startLocalOnlyHotspot(object : WifiManager.LocalOnlyHotspotCallback() {
        override fun onStarted(reservation: WifiManager.LocalOnlyHotspotReservation) {
          super.onStarted(reservation)
          hotspotReservation = reservation
          
          // Android O (API 26) uses different approach compared to later versions
          val ssid: String
          val passphrase: String
          
          if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) { // Android 10+
            val config = reservation.softApConfiguration
            ssid = config?.ssid ?: "Unknown SSID"
            passphrase = config?.passphrase ?: "Unknown Key"
          } else { // Android 8.0-9.0
            // For older versions, use reflection to access the WifiConfiguration
            val wifiConfig = reservation.javaClass.getDeclaredMethod("getWifiConfiguration").invoke(reservation) as? WifiConfiguration
            ssid = wifiConfig?.SSID?.trim('"') ?: "Unknown SSID"
            passphrase = wifiConfig?.preSharedKey?.trim('"') ?: "Unknown Key"
          }
          
          Log.d(TAG, "Hotspot started with SSID: $ssid")
          
          mainScope.launch(Dispatchers.IO) {
            val ipAddress = waitForIp()
            val info = "SSID=$ssid\nKey=$passphrase\nIP=$ipAddress"
            withContext(Dispatchers.Main) {
              result.success(info)
            }
          }
        }

        override fun onFailed(reason: Int) {
          super.onFailed(reason)
          Log.e(TAG, "Failed to start hotspot with reason code: $reason")
          result.error("HOTSPOT_FAILED", "Failed with reason code $reason", null)
        }
      }, null)
    } else {
      result.error("UNSUPPORTED", "API < 26 is not supported", null)
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
}
