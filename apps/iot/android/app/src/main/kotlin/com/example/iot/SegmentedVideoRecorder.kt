package com.example.iot

import android.content.Context
import android.content.Intent
import android.hardware.camera2.*
import android.media.MediaCodec
import android.media.MediaCodec.BufferInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.media.MediaScannerConnection
import android.media.MediaCodecInfo
import android.net.Uri
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.os.StatFs
import android.util.Log
import android.view.Surface
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * SegmentedVideoRecorder records continuous video and splits it into
 * 10-second segments at I-frame boundaries automatically.
 * Files are saved under Movies/Aclick and registered to MediaStore.
 */
class SegmentedVideoRecorder(
    private val context: Context,
    private val cameraId: String
) : MediaCodec.Callback() {
    companion object {
        private const val TAG = "SegmentedVideoRecorder"
        private const val MIME_TYPE = "video/avc"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 2            // GOP size in seconds
        private const val BIT_RATE = 2_000_000            // 2 Mbps
        private const val SEGMENT_DURATION_US = 10_000_000L // 10 seconds
        private const val DIR_NAME = "Aclick"           // under Movies/
        private const val MAX_STORAGE_MB = 32L * 1024    // 32 GB default
    }

    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null

    private lateinit var encoder: MediaCodec
    private lateinit var codecThread: HandlerThread
    private lateinit var codecHandler: Handler
    private lateinit var inputSurface: Surface

    private var currentMuxer: MediaMuxer? = null
    private var videoTrackIndex = -1
    private var segmentStartTimeUs = -1L
    private var segmentIndex = 0
    private var lastFilePath: String? = null

    /** Initializes encoder and opens camera. */
    fun init() {
        prepareEncoder()
        openCamera()
    }

    /** Starts segmented recording, auto-inits if needed. */
    fun startRecording() {
        Log.d(TAG, "startRecording() called")
        if (!::encoder.isInitialized) init()
        segmentIndex = 0
        segmentStartTimeUs = -1L
        createNewMuxer()
        buildCaptureSession()
    }

    /** Signals end-of-stream; cleanup on callback. */
    fun stopRecording() {
        Log.d(TAG, "stopRecording() called")
        encoder.signalEndOfInputStream()
        captureSession?.stopRepeating()
        captureSession?.abortCaptures()
    }

    /** Returns storage status for segment directory. */
    fun getStorageStatus(): Map<String, Any> {
        val dir = getOutputDir()
        val files = dir.listFiles() ?: emptyArray()
        val count = files.size
        val totalMB = files.sumOf { it.length() } / (1024 * 1024)
        val availableMB = StatFs(dir.path).availableBytes / (1024 * 1024)
        return mapOf(
            "totalSegmentSizeMB" to totalMB,
            "availableSpaceMB" to availableMB,
            "segmentCount" to count,
            "maxStorageSizeMB" to MAX_STORAGE_MB
        )
    }

    // MediaCodec.Callback implementations
    override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
        // Not used: we push data via Surface input.
    }

    override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: BufferInfo) {
        if (info.size <= 0) {
            codec.releaseOutputBuffer(index, false)
            return
        }
        val pts = info.presentationTimeUs
        if (segmentStartTimeUs < 0) {
            segmentStartTimeUs = pts
            Log.d(TAG, "New segment start PTS=$segmentStartTimeUs")
        }
        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
        if (pts - segmentStartTimeUs >= SEGMENT_DURATION_US && isKey) {
            Log.d(TAG, "Rotating at PTS=$pts elapsed=${pts - segmentStartTimeUs}")
            // close old segment
            currentMuxer?.stop()
            currentMuxer?.release()
            refreshMedia(lastFilePath)
            // start new
            createNewMuxer()
        }
        // write frame
        val buffer = codec.getOutputBuffer(index)!!
        currentMuxer?.writeSampleData(videoTrackIndex, buffer, info)
        codec.releaseOutputBuffer(index, false)
        // handle EOS
        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
            Log.d(TAG, "EOS reached, cleaning up")
            releaseResources()
            refreshMedia(lastFilePath)
        }
    }

    override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
        Log.e(TAG, "Encoder error", e)
        releaseResources()
    }

    override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
        // No-op
    }

    // Internal helpers
    private fun prepareEncoder() {
        codecThread = HandlerThread("CodecThread").apply { start() }
        codecHandler = Handler(codecThread.looper)
        encoder = MediaCodec.createEncoderByType(MIME_TYPE).apply {
            val fmt = MediaFormat.createVideoFormat(MIME_TYPE, 1920, 1080).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
            }
            configure(fmt, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            setCallback(this@SegmentedVideoRecorder, codecHandler)
            inputSurface = createInputSurface()
            start()
        }
    }

    private fun openCamera() {
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(device: CameraDevice) {
                cameraDevice = device
            }
            override fun onDisconnected(device: CameraDevice) {
                Log.w(TAG, "Camera disconnected")
                device.close()
                cameraDevice = null
            }
            override fun onError(device: CameraDevice, error: Int) {
                Log.e(TAG, "Camera error $error")
                device.close()
                cameraDevice = null
            }
        }, codecHandler)
    }

    private fun buildCaptureSession() {
        cameraDevice?.createCaptureSession(
            listOf(inputSurface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    session.setRepeatingRequest(
                        cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                            .apply { addTarget(inputSurface) }.build(),
                        null, codecHandler
                    )
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "CaptureSession configure failed")
                }
            }, codecHandler
        )
    }

    private fun createNewMuxer() {
        val base = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
        val dir = File(base, DIR_NAME).apply { if (!exists()) mkdirs() }
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())
        val name = "${ts}_seg${segmentIndex++}.mp4"
        val path = File(dir, name).absolutePath
        lastFilePath = path
        Log.d(TAG, "Creating muxer: $path")
        currentMuxer = MediaMuxer(path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4).apply {
            videoTrackIndex = addTrack(encoder.outputFormat)
            start()
        }
        segmentStartTimeUs = -1L
    }

    private fun getOutputDir(): File =
        File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES), DIR_NAME)

    /**
     * Notifies media scanner to index the given file path.
     */
    private fun refreshMedia(path: String?) {
        if (path == null) return
        val file = File(path)
        try {
            if (android.os.Build.VERSION.SDK_INT < 29) {
                context.sendBroadcast(
                    Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(file)))
            } else {
                MediaScannerConnection.scanFile(
                    context,
                    arrayOf(file.toString()),
                    arrayOf("video/mp4"),
                    null
                )
            }
            Log.d(TAG, "Media refreshed: $path")
        } catch (e: Exception) {
            Log.e(TAG, "Media refresh error", e)
        }
    }

    private fun releaseResources() {
        try { encoder.stop() } catch (_: Exception) {}
        try { encoder.release() } catch (_: Exception) {}
        try { currentMuxer?.stop() } catch (_: Exception) {}
        try { currentMuxer?.release() } catch (_: Exception) {}
        captureSession?.close()
        cameraDevice?.close()
        try { if (codecThread.isAlive) codecThread.quitSafely() } catch (_: Exception) {}
        Log.d(TAG, "Resources released")
    }
}
