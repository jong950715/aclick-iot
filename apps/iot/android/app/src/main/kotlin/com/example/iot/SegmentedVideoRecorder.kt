@file:OptIn(
    kotlinx.coroutines.ExperimentalCoroutinesApi::class,
    kotlin.ExperimentalStdlibApi::class
)

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
import kotlinx.coroutines.launch
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.withContext
import com.googlecode.mp4parser.authoring.Movie
import com.googlecode.mp4parser.authoring.Track
import com.googlecode.mp4parser.authoring.builder.DefaultMp4Builder
import com.googlecode.mp4parser.authoring.container.mp4.MovieCreator
import com.googlecode.mp4parser.authoring.tracks.AppendTrack
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.asSharedFlow
import kotlin.coroutines.ContinuationInterceptor
import kotlinx.coroutines.cancelAndJoin

/**
 * SegmentedVideoRecorder records continuous video and splits it into
 * 10-second segments at I-frame boundaries automatically.
 * It also allows merging segments around an event timestamp using mp4parser.
 */
/**
 * 레코더 상태 및 이벤트를 표현하는 봉인 클래스
 */
sealed class RecorderEvent {
    /** 녹화 준비 완료 */
    object Ready : RecorderEvent()
    /** 녹화 시작됨 */
    object Started : RecorderEvent()
    /** 새 세그먼트 생성됨 */
    data class SegmentCreated(val segment: Segment) : RecorderEvent()
    /** 녹화 중단됨 */
    object Stopped : RecorderEvent()
    /** 오류 발생 */
    data class Error(val exception: Exception, val message: String = exception.message ?: "Unknown error") : RecorderEvent()
}

@OptIn(ExperimentalCoroutinesApi::class)
class SegmentedVideoRecorder(
    private val context: Context,
    private val cameraId: String,
    private val segmentRepo: SegmentRepository = MediaStoreSegmentRepository(context),
    private val appScope: CoroutineScope
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

    // 미디어 뮤서 작업을 위한 단일 스레드 컨텍스트
    private val recorderCtx = kotlinx.coroutines.newSingleThreadContext("RecorderThread")
    // 레코더 전용 코루틴 스코프 - 미디어 작업 전용
    private val recorderJob = Job()
    private val recorderScope = CoroutineScope(recorderCtx + recorderJob)
    
    // 레코더 상태 이벤트 Flow
    private val _eventFlow = MutableSharedFlow<RecorderEvent>(extraBufferCapacity = 10)
    val eventFlow = _eventFlow.asSharedFlow()
    
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
        
        // 녹화 시작 이벤트 알림
        recorderScope.launch {
            _eventFlow.emit(RecorderEvent.Started)
        }
        
        // 카메라 세션 시작 - 실제 뮤서 생성은 onOutputFormatChanged에서 수행
        inputSurface?.let { startCaptureSession(it) }
    }

    fun stopRecording() {
        encoder?.signalEndOfInputStream()
        Log.d(TAG, "Recording stop requested")
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
        
        val buffer = codec.getOutputBuffer(index)!!
        val pts = info.presentationTimeUs
        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
        val isEos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
        
        // 논블로킹으로 recorderCtx에 작업 위임
        recorderScope.launch {
            try {
                if (segmentStartTimeUs < 0) {
                    segmentStartTimeUs = pts
                }
                
                // 뮤서가 없는 경우 생성
                if (muxer == null) {
                    initializeSegmentAndMuxer()
                }
                
                // 이제 muxer가 반드시 초기화되어 있음
                check(muxer != null) { "Muxer is not initialized" }
                check(videoTrackIndex >= 0) { "Video track is not added" }
                
                muxer?.writeSampleData(videoTrackIndex, buffer, info)
                
                // 세그먼트 분할 확인
                if (shouldRotate(pts, isKey)) {
                    rotateSegment(pts)
                }
                
                if (isEos) {
                    closeCurrentMuxer(pts)
                    _eventFlow.tryEmit(RecorderEvent.Stopped)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error processing output buffer", e)
                _eventFlow.tryEmit(RecorderEvent.Error(e, "Failed to process video frame: ${e.message}"))
            }
        }
        
        // 코덱 스레드 논블로킹 유지
        codec.releaseOutputBuffer(index, false)
        
        // 스트림 종료 시 리소스 해제
        if (isEos) {
            release()
        }
    }

    override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
        // 포맷이 변경될 때 MediaFormat 정보로 트랙 추가 및 뮤서 시작
        recorderScope.launch {
            try {
                // MediaCodec.onOutputFormatChanged는 코덱이 포맷을 확정했을 때 호출됨
                // 이 시점에서 트랙을 추가하는 것이 가장 적절함
                if (muxer == null) {
                    // 세그먼트와 뮤서 초기화 - 단일 진입점
                    initializeSegmentAndMuxer(format)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error in onOutputFormatChanged", e)
                _eventFlow.tryEmit(RecorderEvent.Error(e, "Failed to initialize recorder: ${e.message}"))
            }
        }
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

    // 리네임: 메서드 이름을 openNewSegment로 변경하고 로직 단순화
    /**
     * 세그먼트 파일 생성만 담당 (IO 작업)
     */
    private suspend fun createSegmentFile(): Segment? {
        val now = System.currentTimeMillis()
        val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date(now))
        val fileName = "${ts}_seg.mp4"
        
        // IO 디스패처로 전환하여 세그먼트 DB 생성
        return withContext(Dispatchers.IO) {
            segmentRepo.insertSegment(fileName, now)
        }
    }

    /**
     * 세그먼트와 뮤서 초기화 (단일 진입점)
     * MediaFormat은 onOutputFormatChanged에서 제공받거나 기존 인코더에서 가져옴
     */
    private suspend fun initializeSegmentAndMuxer(format: MediaFormat? = null) {
        // 올바른 디스패처에서 실행 중인지 확인
        check(coroutineContext[CoroutineDispatcher] == recorderCtx) { 
            "Must be called in RecorderContext" 
        }
        
        try {
            // 세그먼트 파일 생성 - IO 작업은 non-blocking으로 처리
            val segment = createSegmentFile()
            currentSegment = segment
            
            segment?.uri?.let { uri ->
                context.contentResolver.openFileDescriptor(uri, "rw")?.use { pfd ->
                    muxer = MediaMuxer(
                        pfd.fileDescriptor, 
                        MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4
                    ).apply {
                        // format 매개변수가 있으면 그것을 사용, 없으면 인코더에서 가져옴
                        val mediaFormat = format ?: encoder!!.outputFormat
                        videoTrackIndex = addTrack(mediaFormat)
                        start()
                        Log.d(TAG, "Muxer started with track $videoTrackIndex")
                    }
                }
            }
            segmentStartTimeUs = -1L
            _eventFlow.tryEmit(RecorderEvent.SegmentCreated(segment!!))
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize segment and muxer", e)
            _eventFlow.tryEmit(RecorderEvent.Error(e, "Failed to create segment: ${e.message}"))
            throw e // 에러 전파하여 호출자가 처리할 수 있게 함
        }
    }
    
    /**
     * 새 세그먼트 생성 - 회전 시 사용
     * recorderCtx 내에서 호출되어야 함
     */
    private suspend fun openNewSegment() {
        // 올바른 디스패처에서 실행 중인지 확인
        check(coroutineContext[CoroutineDispatcher] == recorderCtx) {
            "Must be called in RecorderContext"
        }
        
        // 단일 진입점 활용
        initializeSegmentAndMuxer()
    }

    /**
     * Merges segments around an event timestamp using mp4parser and writes directly to MediaStore.
     */
    suspend fun createEventClip(eventTimeMs: Long): String? {
        val TAG = "EventMuxParser"
        val fromMs = eventTimeMs - 30_000L
        val toMs = eventTimeMs + 10_000L

//        val segments = runBlocking { segmentRepo.querySegments(fromMs, toMs) }
        val segments = segmentRepo.querySegments(fromMs, toMs)
        Log.d(TAG, "querySegments -> ${segments.size} segs  [$fromMs,$toMs]")
        if (segments.isEmpty()) return null

        val eventName = "${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date())}_event.mp4"
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, eventName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/AclickEvents")
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
        return eventName
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

    /**
     * 현재 세그먼트를 닫고 새 세그먼트를 생성하는 함수
     * recorderCtx 내에서만 호출되어야 함
     */
    private suspend fun rotateSegment(endPtsUs: Long) {
        check(coroutineContext[CoroutineDispatcher] == recorderCtx) { 
            "Must be called in RecorderContext" 
        }
        
        // 현재 뮤서 닫기
        closeCurrentMuxer(endPtsUs)
        // 새 세그먼트 생성 - suspend 함수로 변경
        openNewSegment()
    }
    
    /**
     * 세그먼트 분할 조건 확인 유틸리티 함수
     */
    private fun shouldRotate(pts: Long, isKeyFrame: Boolean): Boolean {
        return pts - segmentStartTimeUs >= SEGMENT_DURATION_US && isKeyFrame
    }

    private suspend fun closeCurrentMuxer(endPtsUs: Long) = withContext(recorderCtx) {
        // 올바른 디스패처에서 실행 중인지 확인
        check(coroutineContext[ContinuationInterceptor] == recorderCtx) {
            "Must be called in RecorderContext" 
        }
        
        try {
            muxer?.stop()
            muxer?.release()
            muxer = null
            videoTrackIndex = -1
            
            currentSegment?.let { seg ->
                val durationMs = (endPtsUs - segmentStartTimeUs) / 1000
                // 세그먼트 업데이트는 IO 작업이므로 별도 코루틴으로 처리
                // appScope를 사용하여 recorderScope가 캔슬되어도 완료되도록 함
                appScope.launch(Dispatchers.IO) { 
                    segmentRepo.updateDuration(seg, durationMs)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error closing muxer", e)
            _eventFlow.tryEmit(RecorderEvent.Error(e, "Failed to close segment: ${e.message}"))
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
        appScope.launch {
            try {
                // 마지막 진행 중인 작업 완료 대기 후 리소스 정리
                recorderJob.cancelAndJoin() // 모든 recorderScope 작업 취소 및 완료 대기
                
                // 최종 뮤서 정리는 recorderJob이 취소된 후 별도로 처리
                withContext(recorderCtx) {
                    if (muxer != null) {
                        try {
                            closeCurrentMuxer(System.nanoTime() / 1000)
                        } catch (e: Exception) {
                            Log.e(TAG, "Error in final muxer cleanup", e)
                        }
                    }
                }
                
                try { encoder?.stop() } catch (e: Exception) { Log.e(TAG, "Error stopping encoder", e) }
                try { encoder?.release() } catch (e: Exception) { Log.e(TAG, "Error releasing encoder", e) }
                
                handlerThread.quitSafely()
                // 모든 작업이 종료된 후 컨텍스트 해제
                recorderCtx.close() 
                
                Log.d(TAG, "Recorder resources fully released")
                _eventFlow.emit(RecorderEvent.Stopped)
            } catch (e: Exception) {
                Log.e(TAG, "Error during recorder release", e)
                _eventFlow.emit(RecorderEvent.Error(e, "Error during cleanup: ${e.message}"))
            }
        }
    }
}
