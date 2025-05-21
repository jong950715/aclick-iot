// In module-level build.gradle.kts, ensure:
// implementation("com.squareup.okhttp3:okhttp:4.9.3")

package com.example.iot

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.NetworkSpecifier
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody

class EphemeralWifiManager(
    private val context: Context
) {
    private val TAG = "EphemeralWifiMgr"
    private val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
    private var currentNetwork: Network? = null

    interface Callback {
        fun onConnected()
        fun onResponse(success: Boolean, code: Int, body: String?)
        fun onError(error: String)
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    fun connectToSsid(ssid: String, passphrase: String, callback: Callback) {
        val specifier = WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
            .setWpa2Passphrase(passphrase)
            .build() as NetworkSpecifier

        val request = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(specifier)
            .build()

        cm.requestNetwork(request, object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                Log.i(TAG, "Ephemeral Wi-Fi connected: $ssid")
                currentNetwork = network
                callback.onConnected()
            }

            override fun onUnavailable() {
                Log.e(TAG, "Failed to connect ephemeral Wi-Fi: $ssid")
                callback.onError("Network unavailable")
                cm.unregisterNetworkCallback(this)
            }
        })
    }

    fun requestOverWifi(
        method: String,
        url: String,
        headers: Map<String, String>? = null,
        body: String? = null,
        callback: Callback
    ) {
        val network = currentNetwork
        if (network == null) {
            callback.onError("No network bound")
            return
        }

        Thread {
            try {
                val builder = Request.Builder().url(url)
                headers?.forEach { entry -> builder.addHeader(entry.key, entry.value) }

                when (method.uppercase()) {
                    "GET" -> builder.get()
                    "POST" -> {
                        val mediaType = "application/json; charset=utf-8".toMediaType()
                        val requestBody = (body ?: "").toRequestBody(mediaType)
                        builder.post(requestBody)
                    }
                    else -> throw IllegalArgumentException("Unsupported method: $method")
                }

                val client = OkHttpClient.Builder()
                    .socketFactory(network.socketFactory)
                    .build()

                client.newCall(builder.build()).execute().use { resp ->
                    val respBody = resp.body?.string()
                    val code = resp.code
                    Log.i(TAG, "HTTP $method @ $url → code=$code")
                    callback.onResponse(resp.isSuccessful, code, respBody)
                }
            } catch (e: Exception) {
                Log.e(TAG, "HTTP request failed", e)
                callback.onError(e.message ?: "unknown error")
            }
        }.start()
    }

    fun dispose() {
        currentNetwork?.let { cm.bindProcessToNetwork(null) }
        currentNetwork = null
    }
}
