package com.aclick.bluetooth_classic

// 이 파일은 더 이상 사용되지 않습니다.
// Flutter 1.12 이후에는 BluetoothClassicPlugin 클래스가 직접 FlutterPlugin 인터페이스를 구현합니다.

/*
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodChannel

/** BluetoothClassicFactory */
class BluetoothClassicFactory : FlutterPlugin {
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.aclick.bluetooth_classic/android")
        val plugin = BluetoothClassicPlugin()
        channel.setMethodCallHandler(plugin)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
*/
