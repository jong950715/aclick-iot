package com.example.iot

import android.Manifest
import android.content.ContentValues
import android.content.Context
import android.hardware.camera2.CameraCaptureSession
import android.hardware.camera2.CameraDevice
import android.hardware.camera2.CameraManager
import android.media.MediaCodec
import android.media.MediaCodec.BufferInfo
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.HandlerThread
import android.provider.MediaStore
import android.util.Log
import android.view.Surface
import androidx.annotation.RequiresPermission
import com.googlecode.mp4parser.authoring.Movie
import com.googlecode.mp4parser.authoring.Track
import com.googlecode.mp4parser.authoring.builder.DefaultMp4Builder
import com.googlecode.mp4parser.authoring.container.mp4.MovieCreator
import com.googlecode.mp4parser.authoring.tracks.AppendTrack
import kotlinx.coroutines.runBlocking
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * SegmentedVideoRecorder records continuous video and splits it into
 * 10-second segments at I-frame boundaries automatically.
 * It also allows merging segments around an event timestamp using mp4parser.
 */
class SegmentedVideoRecorder(
    private val context: Context,
    private val cameraId: String,
    private val segmentRepo: SegmentRepository = MediaStoreSegmentRepository(context)
) : MediaCodec.Callback() {

    companion object {
        private const val TAG = "SegmentedVideoRecorder"
        private const val MIME_TYPE = "video/avc"
        private const val FRAME_RATE = 30
        private const val I_FRAME_INTERVAL = 2              // GOP size in seconds
        private const val BIT_RATE = 2_000_000               // 2 Mbps
        private const val SEGMENT_DURATION_US = 10_000_000L  // 10 seconds
    }

    private var encoder: MediaCodec? = null
    private var inputSurface: Surface? = null
    private var muxer: MediaMuxer? = null
    private var currentSegment: Segment? = null
    private var videoTrackIndex = -1
    private var segmentStartTimeUs = -1L

    private lateinit var handlerThread: HandlerThread
    private lateinit var handler: Handler
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null

    @RequiresPermission(Manifest.permission.CAMERA)
    fun init() {
        handlerThread = HandlerThread("CodecThread").apply { start() }
        handler = Handler(handlerThread.looper)
        prepareEncoder()
        openCamera()
    }

    @RequiresPermission(Manifest.permission.CAMERA)
    fun startRecording() {
        if (encoder == null) init()
        segmentStartTimeUs = -1L
        createNewSegment()
        inputSurface?.let { startCaptureSession(it) }
    }

    fun stopRecording() {
        encoder?.signalEndOfInputStream()
    }

    // Implement required MediaCodec.Callback methods
    override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {
        // Not used for Surface input
    }

    override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: BufferInfo) {
        if (info.size <= 0) {
            codec.releaseOutputBuffer(index, false)
            return
        }
        val pts = info.presentationTimeUs
        if (segmentStartTimeUs < 0) {
            segmentStartTimeUs = pts
        }
        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
        if (pts - segmentStartTimeUs >= SEGMENT_DURATION_US && isKey) {
            closeCurrentMuxer(pts)
            createNewSegment()
        }
        val buffer = codec.getOutputBuffer(index)!!
        muxer?.writeSampleData(videoTrackIndex, buffer, info)
        codec.releaseOutputBuffer(index, false)

        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
            closeCurrentMuxer(pts)
            release()
        }
    }

    override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
        // Handle format changes if needed
    }

    override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
        Log.e(TAG, "Encoder error", e)
        release()
    }

    private fun prepareEncoder() {
        encoder = MediaCodec.createEncoderByType(MIME_TYPE).apply {
            val format = MediaFormat.createVideoFormat(MIME_TYPE, 1920, 1080).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
                setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
            }
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            setCallback(this@SegmentedVideoRecorder, handler)
            inputSurface = createInputSurface()
            start()
        }
    }

    private fun createNewSegment() {
        val now = System.currentTimeMillis()
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date(now))
        val fileName = "${ts}_seg.mp4"

        currentSegment = runBlocking { segmentRepo.insertSegment(fileName, now) }
        currentSegment?.uri?.let { uri ->
            context.contentResolver.openFileDescriptor(uri, "rw")?.use { pfd ->
                muxer = MediaMuxer(
                    pfd.fileDescriptor,
                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                ).apply {
                    videoTrackIndex = addTrack(encoder!!.outputFormat)
                    start()
                }
            }
        }
        segmentStartTimeUs = -1L
    }

    /**
     * Merges segments around an event timestamp using mp4parser and writes directly to MediaStore.
     */
    fun createEventClip(eventTimeMs: Long): Uri? {
        val TAG = "EventMuxParser"
        val fromMs = eventTimeMs - 10_000L
        val toMs = eventTimeMs + 10_000L

        val segments = runBlocking { segmentRepo.querySegments(fromMs, toMs) }
        Log.d(TAG, "querySegments -> ${segments.size} segs  [$fromMs,$toMs]")
        if (segments.isEmpty()) return null

        val eventName = "${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}_event.mp4"
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, eventName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/Aclick/Events")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val outUri = context.contentResolver.insert(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
        Log.d(TAG, "output uri = $outUri")

        val videoTracks = mutableListOf<Track>()
        val audioTracks = mutableListOf<Track>()
        for (seg in segments) {
            val path = uriToFilePath(seg.uri)
            if (path == null) {
                Log.w(TAG, "cannot resolve path for ${seg.uri}")
                continue
            }
            val movie = MovieCreator.build(path)
            movie.tracks.forEach { track ->
                when (track.handler) {
                    "vide" -> videoTracks += track
                    "soun" -> audioTracks += track
                }
            }
        }

        val result = Movie().apply {
            if (videoTracks.isNotEmpty()) addTrack(AppendTrack(*videoTracks.toTypedArray()))
            if (audioTracks.isNotEmpty()) addTrack(AppendTrack(*audioTracks.toTypedArray()))
        }
        val container = DefaultMp4Builder().build(result)

        context.contentResolver.openFileDescriptor(outUri, "rw")?.use { pfd ->
            FileOutputStream(pfd.fileDescriptor).channel.use { fc -> container.writeContainer(fc) }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            context.contentResolver.update(outUri, values, null, null)
        }

        Log.d(TAG, "merge done, uri=$outUri")
        return outUri
    }

    /**
     * Resolves a content URI to an absolute file system path via MediaStore DATA column.
     */
    private fun uriToFilePath(uri: Uri): String? {
        val proj = arrayOf(MediaStore.MediaColumns.DATA)
        context.contentResolver.query(uri, proj, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val idx = cursor.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
                return cursor.getString(idx)
            }
        }
        return null
    }

    private fun closeCurrentMuxer(endPtsUs: Long) {
        muxer?.stop()
        muxer?.release()
        muxer = null
        currentSegment?.let { seg ->
            val durationMs = (endPtsUs - segmentStartTimeUs) / 1000
            runBlocking { segmentRepo.updateDuration(seg, durationMs) }
        }
    }

    @RequiresPermission(Manifest.permission.CAMERA)
    private fun openCamera() {
        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
        mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
            override fun onOpened(device: CameraDevice) { cameraDevice = device }
            override fun onDisconnected(device: CameraDevice) { device.close(); cameraDevice = null }
            override fun onError(device: CameraDevice, error: Int) { device.close(); cameraDevice = null }
        }, handler)
    }

    private fun startCaptureSession(surface: Surface) {
        cameraDevice?.createCaptureSession(
            listOf(surface),
            object : CameraCaptureSession.StateCallback() {
                override fun onConfigured(session: CameraCaptureSession) {
                    captureSession = session
                    val req = cameraDevice!!.createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
                        .apply { addTarget(surface) }.build()
                    session.setRepeatingRequest(req, null, handler)
                }
                override fun onConfigureFailed(session: CameraCaptureSession) {
                    Log.e(TAG, "CaptureSession configure failed")
                }
            }, handler)
    }

    private fun release() {
        try { encoder?.stop() } catch (_: Exception) {}
        try { encoder?.release() } catch (_: Exception) {}
        handlerThread.quitSafely()
        Log.d(TAG, "Recorder released")
    }
}
