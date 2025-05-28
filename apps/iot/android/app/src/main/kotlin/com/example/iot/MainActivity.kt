package com.example.iot

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import com.example.my_volume_app.VolumeKeyActivity

class MainActivity : VolumeKeyActivity(){
    private lateinit var videoMethodChannel: VideoMethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(VideoMethodChannel())
    }
}
