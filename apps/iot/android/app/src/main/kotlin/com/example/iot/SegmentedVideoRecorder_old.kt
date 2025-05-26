//package com.example.iot
//
//import android.Manifest
//import android.content.ContentValues
//import android.content.Context
//import android.hardware.camera2.*
//import android.media.MediaCodec
//import android.media.MediaCodec.BufferInfo
//import android.media.MediaCodecInfo
//import android.media.MediaExtractor
//import android.media.MediaFormat
//import android.media.MediaMuxer
//import android.net.Uri
//import android.os.Build
//import android.os.Environment
//import android.os.Handler
//import android.os.HandlerThread
//import android.provider.MediaStore
//import android.util.Log
//import android.view.Surface
//import androidx.annotation.RequiresPermission
//import kotlinx.coroutines.runBlocking
//import java.nio.ByteBuffer
//import java.text.SimpleDateFormat
//import java.util.Date
//import java.util.Locale
//
///**
// * SegmentedVideoRecorder records continuous video and splits it into
// * 10-second segments at I-frame boundaries automatically.
// * Files are saved under Movies/Aclick and registered to MediaStore.
// */
///**
// * Records continuous video in fixed-duration segments and handles event clipping.
// */
///**
// * Records continuous video in fixed-duration segments and handles event clipping.
// */
//class SegmentedVideoRecorder_old(
//    private val context: Context,
//    private val cameraId: String,
//    private val segmentRepo: SegmentRepository = MediaStoreSegmentRepository(context)
//) : MediaCodec.Callback() {
//    companion object {
//        private const val TAG = "SegmentedVideoRecorder"
//        private const val MIME_TYPE = "video/avc"
//        private const val FRAME_RATE = 30
//        private const val I_FRAME_INTERVAL = 2              // GOP size in seconds
//        private const val BIT_RATE = 2_000_000               // 2 Mbps
//        private const val SEGMENT_DURATION_US = 10_000_000L  // 10 seconds
//    }
//
//    private var encoder: MediaCodec? = null
//    private var inputSurface: Surface? = null
//    private var muxer: MediaMuxer? = null
//    private var currentSegment: Segment? = null
//    private var videoTrackIndex = -1
//    private var segmentStartTimeUs = -1L
//
//    private lateinit var handlerThread: HandlerThread
//    private lateinit var handler: Handler
//    private var cameraDevice: CameraDevice? = null
//    private var captureSession: CameraCaptureSession? = null
//
//    @RequiresPermission(Manifest.permission.CAMERA)
//    fun init() {
//        handlerThread = HandlerThread("CodecThread").apply { start() }
//        handler = Handler(handlerThread.looper)
//        prepareEncoder()
//        openCamera()
//    }
//
//    @RequiresPermission(Manifest.permission.CAMERA)
//    fun startRecording() {
//        if (encoder == null) init()
//        segmentStartTimeUs = -1L
//        createNewSegment()
//        startCaptureSession(inputSurface!!)
//    }
//
//    fun stopRecording() {
//        encoder?.signalEndOfInputStream()
//    }
//
//    override fun onInputBufferAvailable(codec: MediaCodec, index: Int) {}
//    override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {}
//
//    override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
//        Log.e(TAG, "Encoder error", e)
//        release()
//    }
//
//    override fun onOutputBufferAvailable(codec: MediaCodec, index: Int, info: BufferInfo) {
//        if (info.size <= 0) {
//            codec.releaseOutputBuffer(index, false)
//            return
//        }
//        val pts = info.presentationTimeUs
//        if (segmentStartTimeUs < 0) {
//            segmentStartTimeUs = pts
//            currentSegment?.let { seg ->
//                runBlocking {
//                    segmentRepo.updateDuration(
//                        seg.copy(startMs = seg.startMs),
//                        seg.durationMs
//                    )
//                }
//            }
//        }
//        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
//        if (pts - segmentStartTimeUs >= SEGMENT_DURATION_US && isKey) {
//            closeCurrentMuxer(pts)
//            createNewSegment()
//        }
//        val buffer = codec.getOutputBuffer(index)!!
//        muxer?.writeSampleData(videoTrackIndex, buffer, info)
//        codec.releaseOutputBuffer(index, false)
//
//        if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
//            closeCurrentMuxer(pts)
//            release()
//        }
//    }
//
//    private fun prepareEncoder() {
//        encoder = MediaCodec.createEncoderByType(MIME_TYPE).apply {
//            val format = MediaFormat.createVideoFormat(MIME_TYPE, 1920, 1080).apply {
//                setInteger(MediaFormat.KEY_COLOR_FORMAT,
//                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface)
//                setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
//                setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
//                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
//            }
//            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
//            setCallback(this@SegmentedVideoRecorder_old, handler)
//            inputSurface = createInputSurface()
//            start()
//        }
//    }
//
//    private fun createNewSegment() {
//        // 동일한 타임스탬프를 사용해 파일명과 DATE_TAKEN을 일치시킵니다.
//        val now = System.currentTimeMillis()
//        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date(now))
//        val fileName = "${ts}_seg.mp4"
//
//        currentSegment = runBlocking { segmentRepo.insertSegment(fileName, now) }
//        currentSegment?.let { seg ->
//            context.contentResolver.openFileDescriptor(seg.uri, "rw")?.use { pfd ->
//                muxer = MediaMuxer(
//                    pfd.fileDescriptor,
//                    MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
//                ).apply {
//                    videoTrackIndex = addTrack(encoder!!.outputFormat)
//                    start()
//                }
//            }
//        }
//        segmentStartTimeUs = -1L
//    }
//
//    private fun closeCurrentMuxer(endPtsUs: Long) {
//        muxer?.stop()
//        muxer?.release()
//        muxer = null
//        currentSegment?.let { seg ->
//            val durationMs = (endPtsUs - segmentStartTimeUs) / 1000
//            runBlocking { segmentRepo.updateDuration(seg, durationMs) }
//        }
//    }
//
//    @RequiresPermission(Manifest.permission.CAMERA)
//    private fun openCamera() {
//        val mgr = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
//        mgr.openCamera(cameraId, object : CameraDevice.StateCallback() {
//            override fun onOpened(device: CameraDevice) {
//                cameraDevice = device
//            }
//            override fun onDisconnected(device: CameraDevice) {
//                device.close()
//                cameraDevice = null
//            }
//            override fun onError(device: CameraDevice, error: Int) {
//                device.close()
//                cameraDevice = null
//            }
//        }, handler)
//    }
//
//    private fun startCaptureSession(surface: Surface) {
//        cameraDevice?.createCaptureSession(
//            listOf(surface),
//            object : CameraCaptureSession.StateCallback() {
//                override fun onConfigured(session: CameraCaptureSession) {
//                    captureSession = session
//                    val reqBuilder = cameraDevice!!
//                        .createCaptureRequest(CameraDevice.TEMPLATE_RECORD)
//                        .apply { addTarget(surface) }
//                    val request: CaptureRequest = reqBuilder.build()
//                    session.setRepeatingRequest(request, null, handler)
//                }
//                override fun onConfigureFailed(session: CameraCaptureSession) {
//                    Log.e(TAG, "CaptureSession configure failed")
//                }
//            }, handler
//        )
//    }
//
//    /**
//     * Creates an event clip merging segments around an event timestamp.
//     */
//    fun createEventClip(eventTimeMs: Long): Uri? {
//        val TAG = "EventMuxParser"
//        val fromMs = eventTimeMs - 10_000
//        val toMs = eventTimeMs + 10_000
//
//        // 1) 쿼리
//        val segments = runBlocking { segmentRepo.querySegments(fromMs, toMs) }
//        Log.d(TAG, "querySegments -> ${segments.size} segs  [$fromMs,$toMs]")
//        if (segments.isEmpty()) return null
//
//        // 2) 출력용 MediaStore URI 준비
//        val eventName = "${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}_event.mp4"
//        val values = ContentValues().apply {
//            put(MediaStore.Video.Media.DISPLAY_NAME, eventName)
//            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
//            if (Build.VERSION.SDK_INT >= 29) {
//                put(
//                    MediaStore.Video.Media.RELATIVE_PATH,
//                    "${Environment.DIRECTORY_MOVIES}/Aclick/Events"
//                )
//                put(MediaStore.Video.Media.IS_PENDING, 1)
//            }
//        }
//        val outUri = contentResolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
//            ?: return null
//        Log.d(TAG, "output uri = $outUri")
//
//        // 3) 세그먼트들 경로로 변환
//        val paths = segments.mapNotNull { seg ->
//            uriToFilePath(this, seg.uri)?.also { Log.d(TAG, "  segment path: $it") }
//        }
//        if (paths.isEmpty()) return null
//
//        // 4) mp4parser 로 Merge
//        //    4-1) 각 세그먼트에서 비디오/오디오 Track 수집
//        val videoTracks = mutableListOf<Track>()
//        val audioTracks = mutableListOf<Track>()
//        for (path in paths) {
//            val movie = MovieCreator.build(path)
//            for (track in movie.tracks) {
//                when (track.handler) {
//                    "vide" -> videoTracks += track
//                    "soun" -> audioTracks += track
//                }
//            }
//        }
//
//        //    4-2) 새 Movie 에 붙이기
//        val result = Movie().apply {
//            if (videoTracks.isNotEmpty())
//                addTrack(AppendTrack(*videoTracks.toTypedArray()))
//            if (audioTracks.isNotEmpty())
//                addTrack(AppendTrack(*audioTracks.toTypedArray()))
//        }
//
//        //    4-3) MP4 컨테이너 생성 & 쓰기
//        val container = DefaultMp4Builder().build(result)
//        contentResolver.openFileDescriptor(outUri, "rw")?.use { pfd ->
//            FileOutputStream(pfd.fileDescriptor).channel.use { fc ->
//                container.writeContainer(fc)
//            }
//        }
//
//        // 5) Pending 해제
//        if (Build.VERSION.SDK_INT >= 29) {
//            values.clear()
//            values.put(MediaStore.Video.Media.IS_PENDING, 0)
//            contentResolver.update(outUri, values, null, null)
//        }
//
//        Log.d(TAG, "merge done, uri=$outUri")
//        return outUri
//    }
//
//    /** content:// URI → 실제 파일 절대경로 반환 (FileUtils 등으로 대체 가능) */
//    fun uriToFilePath(context: Context, uri: Uri): String? {
//        // 예시: MediaStore 자체 DB에서 _data 컬럼 읽기
//        val proj = arrayOf(MediaStore.MediaColumns.DATA)
//        context.contentResolver.query(uri, proj, null, null, null)?.use { c ->
//            if (c.moveToFirst()) {
//                val idx = c.getColumnIndexOrThrow(MediaStore.MediaColumns.DATA)
//                return c.getString(idx)
//            }
//        }
//        return null
//    }
//
//    private fun release() {
//        try {
//            encoder?.stop()
//        } catch (_: Exception) {
//        }
//        try {
//            encoder?.release()
//        } catch (_: Exception) {
//        }
//        handlerThread.quitSafely()
//        Log.d(TAG, "Recorder released")
//    }
//}
