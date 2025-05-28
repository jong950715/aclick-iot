package com.example.iot

import android.app.Activity
import android.content.Context
import android.os.Build
import androidx.core.app.ActivityCompat
import android.Manifest
import android.content.pm.PackageManager
import androidx.annotation.RequiresPermission
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Flutter ↔ Android bridge for video segmentation
 * Uses Camera2 + MediaCodec + MediaMuxer pattern via SegmentedVideoRecorder
 */
class VideoMethodChannel() : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {
    // 채널 이름: Flutter 쪽과 동일하게 맞춤
    private val CHANNEL_NAME = "com.example.iot/video_recording"
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var recorder: SegmentedVideoRecorder? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        context = binding.activity.applicationContext
        recorder = SegmentedVideoRecorder(context!!, getDefaultCameraId())
    }

    override fun onDetachedFromActivityForConfigChanges() {}
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        onAttachedToActivity(binding)
    }
    override fun onDetachedFromActivity() {
        activity = null
        context = null
        recorder = null
    }

    @RequiresPermission(Manifest.permission.CAMERA)
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val rec = recorder ?: run {
            result.error("NO_RECORDER", "Recorder not initialized", null)
            return
        }
        when (call.method) {
            "checkPermissions" -> result.success(ensurePermissions())
//            "setResolution" -> {
//                val w = call.argument<Int>("width") ?: DEFAULT_WIDTH
//                val h = call.argument<Int>("height") ?: DEFAULT_HEIGHT
//                rec.setResolution(w, h)
//                result.success(null)
//            }
//            "setBitrate" -> {
//                val bps = call.argument<Int>("bitrate") ?: DEFAULT_BITRATE
//                rec.setBitrate(bps)
//                result.success(null)
//            }
//            "setFrameRate" -> {
//                val fpsVal = call.argument<Int>("fps") ?: DEFAULT_FPS
//                rec.setFrameRate(fpsVal)
//                result.success(null)
//            }
//            "setSegmentDuration" -> {
//                val sec = call.argument<Long>("seconds") ?: DEFAULT_SEGMENT_DURATION
//                rec.setSegmentDuration(sec)
//                result.success(null)
//            }
//            "setGopDuration" -> {
//                val sec = call.argument<Int>("seconds") ?: DEFAULT_GOP_INTERVAL
//                rec.setGopDuration(sec)
//                result.success(null)
//            }
            "startRecording" -> {
                rec.startRecording()
                result.success(true)
            }
            "stopRecording" -> {
                rec.stopRecording()
                result.success(true)
            }
//            "createEventClip" -> {
//                val eventTimeMs = call.argument<Long>("eventTimeMs")?: return result.error("NO_TIME", "eventTimeMs 누락", null)
//                val eventName = rec.createEventClip(eventTimeMs)
//                result.success(eventName)
//            }
            "createEventClip" -> {
                val eventTimeMs = call.argument<Long>("eventTimeMs")
                    ?: return result.error("NO_TIME", "eventTimeMs 누락", null)

                // ② Main 스레드에서 코루틴으로 비동기 실행
                CoroutineScope(Dispatchers.Main).launch{
                    try {
                        // ③ IO 디스패처 내부로 넘어가 query·병합 작업 수행
                        val name = rec.createEventClip(eventTimeMs)
                        result.success(name)
                    } catch (e: Exception) {
                        result.error("CLIP_ERROR", e.message, null)
                    }
                }
            }
//            "isRecording" -> result.success(rec.isRecording()) TODO
//            "getStorageStatus" -> result.success(rec.getStorageStatus()) TODO
            else -> result.notImplemented()
        }
    }

    /**
     * 권한 확인 (동기)
     */
    private fun ensurePermissions(): Boolean {
        val act = activity ?: return false
        val needed = mutableListOf(
            Manifest.permission.CAMERA,
            Manifest.permission.RECORD_AUDIO
        )
        if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
            needed += Manifest.permission.WRITE_EXTERNAL_STORAGE
        }
        return needed.all {
            ActivityCompat.checkSelfPermission(act, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun getDefaultCameraId(): String {
        val mgr = context!!.getSystemService(Context.CAMERA_SERVICE) as android.hardware.camera2.CameraManager
        return mgr.cameraIdList.firstOrNull() ?: "0"
    }

    companion object {
        private const val DEFAULT_WIDTH = 1920
        private const val DEFAULT_HEIGHT = 1080
        private const val DEFAULT_FPS = 30
        private const val DEFAULT_BITRATE = 8_000_000
        private const val DEFAULT_SEGMENT_DURATION = 10L
        private const val DEFAULT_GOP_INTERVAL = 1
    }
}
