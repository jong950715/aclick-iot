// VolumeKeyActivity.kt
package com.example.my_volume_app

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel

open class VolumeKeyActivity: FlutterFragmentActivity() {
    private val CHANNEL = "custom/volume"

    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP && event.action == KeyEvent.ACTION_DOWN) {
            // Flutter 쪽에 볼륨 업 신호 전달
            MethodChannel(
                flutterEngine!!.dartExecutor.binaryMessenger,
                CHANNEL
            ).invokeMethod("onVolumeUp", null)
            return true  // 시스템 볼륨 조절을 막고, 우리가 처리함
        }
        return super.onKeyDown(keyCode, event)
    }
}
