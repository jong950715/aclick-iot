// VolumeKeyActivity.kt
package com.example.my_volume_app

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

open class VolumeKeyActivity: FlutterActivity() {
    private val CHANNEL = "custom/volume"

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP && event.action == KeyEvent.ACTION_DOWN) {
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod("onVolumeUp", null)
            return true  // 시스템 볼륨 차단
        }
        return super.dispatchKeyEvent(event)
    }
}
