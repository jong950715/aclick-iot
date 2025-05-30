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
import androidx.annotation.RequiresApi
import androidx.annotation.RequiresPermission
import com.googlecode.mp4parser.authoring.Movie
import com.googlecode.mp4parser.authoring.Track
import com.googlecode.mp4parser.authoring.builder.DefaultMp4Builder
import com.googlecode.mp4parser.authoring.container.mp4.MovieCreator
import com.googlecode.mp4parser.authoring.tracks.AppendTrack
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.launch
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.ExecutorService
import java.util.concurrent.ThreadFactory
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

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

@RequiresApi(Build.VERSION_CODES.LOLLIPOP)
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

    // ① Recorder 로직 처리 위한 단일 HandlerThread
    private val recorderThread = HandlerThread("RecorderThread").apply { start() }
    private val recorderHandler = Handler(recorderThread.looper)

    // ② I/O 작업 전용 Executor
    private val ioExecutor = Executors.newSingleThreadExecutor(
        ThreadFactory { runnable ->
            Thread(runnable, "IoThread").apply { isDaemon = true }
        }
    )
    
    // 레코더 상태 이벤트 Flow
    private val _eventFlow = MutableSharedFlow<RecorderEvent>(extraBufferCapacity = 10)
    val eventFlow = _eventFlow.asSharedFlow()
    
    private lateinit var handlerThread: HandlerThread
    private lateinit var handler: Handler
    private var cameraDevice: CameraDevice? = null
    private var captureSession: CameraCaptureSession? = null

    @RequiresApi(Build.VERSION_CODES.M)
    @RequiresPermission(Manifest.permission.CAMERA)
    fun init() {
        handlerThread = HandlerThread("CodecThread").apply { start() }
        handler = Handler(handlerThread.looper)
        prepareEncoder()
        openCamera()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun prepareEncoder() {
        encoder = MediaCodec.createEncoderByType(MIME_TYPE).apply {
            val format = MediaFormat.createVideoFormat(MIME_TYPE, 1920, 1080).apply {
                setInteger(
                    MediaFormat.KEY_COLOR_FORMAT,
                    MediaCodecInfo.CodecCapabilities.COLOR_FormatSurface
                )
                setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
                setInteger(MediaFormat.KEY_FRAME_RATE, FRAME_RATE)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, I_FRAME_INTERVAL)
            }
            configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            // recorderHandler를 사용하여 모든 콜백이 recorderThread에서 실행되도록 함
            setCallback(this@SegmentedVideoRecorder, recorderHandler)
            inputSurface = createInputSurface()
            start()
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    @RequiresPermission(Manifest.permission.CAMERA)
    fun startRecording() {
        if (encoder == null) init()
        segmentStartTimeUs = -1L
        
        // 녹화 시작 이벤트 알림
        _eventFlow.tryEmit(RecorderEvent.Started)
        
        // 카메라 세션 시작 - 실제 뮤서 생성은 onOutputFormatChanged에서 수행
        inputSurface?.let { surface -> startCaptureSession(surface) }
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
        // 크기가 0 이하인 프레임은 스킵 (실행 전 필터링)
        if (info.size <= 0) {
            codec.releaseOutputBuffer(index, false)
            return
        }

        val buffer = codec.getOutputBuffer(index) ?: return
        val pts = info.presentationTimeUs
        val isKey = info.flags and MediaCodec.BUFFER_FLAG_KEY_FRAME != 0
        val isEos = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0

        // 이미 recorderThread에서 실행 중이므로 바로 작업 수행 (atomic 처리)
        try {
            // --- atomic 시작 -----------------------------------
            // (1) 최초 PTS 설정
            if (segmentStartTimeUs < 0) {
                segmentStartTimeUs = pts
            }

            // (2) muxer 초기화
            if (muxer == null) {
                Log.d("muxer is null", "pts: $pts, isKey: $isKey, isEos: $isEos")
                initializeSegmentAndMuxerSync(null)
            }

            // 이제 muxer가 반드시 초기화되어 있음
            check(muxer != null) { "Muxer is not initialized" }
            check(videoTrackIndex >= 0) { "Video track is not added" }

            // (3) 세그먼트 분할 확인
            if (shouldRotate(pts, isKey)) {
                Log.d("newSegment", "pts: $pts, isKey: $isKey, isEos: $isEos")
                rotateSegmentSync(pts)
            }

            // (4) 버퍼 쓰기
            muxer?.writeSampleData(videoTrackIndex, buffer, info)

            // (5) 버퍼 반환 (atomic 순서 중요: writeSampleData 후 releaseOutputBuffer)
            codec.releaseOutputBuffer(index, false)
            // --- atomic 끝 -------------------------------------

            if (isEos) {
                closeSegmentSync(pts)
                _eventFlow.tryEmit(RecorderEvent.Stopped)
                // 스트림 종료 시 리소스 해제
                releaseSync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error processing output buffer", e)
            _eventFlow.tryEmit(
                RecorderEvent.Error(
                    e,
                    "Failed to process video frame: ${e.message}"
                )
            )
            // 예외 발생시에도 버퍼 반환 반드시 필요
            codec.releaseOutputBuffer(index, false)
        }
    }

    override fun onOutputFormatChanged(codec: MediaCodec, format: MediaFormat) {
        // 포맷이 변경될 때 MediaFormat 정보로 트랙 추가 및 뮤서 시작
        // 이미 recorderThread에서 실행중이므로 바로 작업 진행
        try {
            // MediaCodec.onOutputFormatChanged는 코덱이 포맷을 확정했을 때 호출됨
            // 이 시점에서 트랙을 추가하는 것이 가장 적절함
            if (muxer == null) {
                // 세그먼트와 뮤서 초기화 - 단일 진입점
                initializeSegmentAndMuxerSync(format)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in onOutputFormatChanged", e)
            _eventFlow.tryEmit(
                RecorderEvent.Error(
                    e,
                    "Failed to initialize recorder: ${e.message}"
                )
            )
        }
    }

    override fun onError(codec: MediaCodec, e: MediaCodec.CodecException) {
        Log.e(TAG, "Encoder error", e)
        release()
    }

    /**
     * 세그먼트 파일 생성 - 동기 버전 (자원 생성만 담당)
     * recorderThread를 블록하지 않고 임시 세그먼트 객체 반환
     */
    private fun createSegmentFileSync(): Segment? {
        try {
            val now = System.currentTimeMillis()
            val ts = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(Date(now))
            val fileName = "${ts}_seg.mp4"
            
            // 임시 세그먼트 객체 생성 (DB 저장 전 임시 URI와 타임스태프만 포함)
            val values = ContentValues().apply {
                put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Video.Media.RELATIVE_PATH, 
                        "${Environment.DIRECTORY_MOVIES}/Aclick")
                    put(MediaStore.Video.Media.IS_PENDING, 1)
                }
            }
            
            // 파일 시스템에 임시 URI 생성 (동기 작업)
            val uri = context.contentResolver.insert(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values) ?: return null
                
            // 임시 세그먼트 객체 생성 - 실제 클래스 생성자에 맞춰 수정
            // ID는 임시값(0), URI는 지금 생성한 값, startMs는 현재 시간, durationMs는 초기값(0)
            val tempSegment = Segment(0, uri, now, 0)
            
            // 현재 세그먼트로 임시 설정 (나중에 실제 ID로 업데이트 예정)
            currentSegment = tempSegment
            
            // DB 추가는 비동기로 처리
            ioExecutor.execute {
                try {
                    // DB에 세그먼트 저장하고 실제 생성된 ID 반환받기
                    kotlinx.coroutines.runBlocking {
                        val insertedSegment = segmentRepo.insertSegment(fileName, now)
                        // 생성된 세그먼트가 유효하고 ID가 있다면 currentSegment 업데이트
                        insertedSegment?.let { segment ->
                            synchronized(this@SegmentedVideoRecorder) {
                                // 새로 생성된 ID로 현재 세그먼트 업데이트
                                currentSegment = tempSegment.copy(id = segment.id)
                                Log.d(TAG, "Updated segment ID from 0 to ${segment.id}")
                            }
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error inserting segment to DB", e)
                }
            }
            
            return tempSegment
        } catch (e: Exception) {
            Log.e(TAG, "Error creating segment file", e)
            return null
        }
    }

    /**
     * 세그먼트와 뮤서 초기화 - 동기 버전 (단일 진입점)
     * MediaFormat은 onOutputFormatChanged에서 제공받거나 기존 인코더에서 가져옴
     */
    private fun initializeSegmentAndMuxerSync(format: MediaFormat? = null) {
        Log.d("newSeg&Muxer", "initializeSegmentAndMuxerSync")
        try {
            // 세그먼트 파일 생성 (동기식)
            val segment = createSegmentFileSync()
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
     * 새 세그먼트 생성 - 회전 시 사용 (동기 버전)
     * recorderExecutor 내에서 호출되어야 함
     */
    private fun openSegmentSync() {
        // 단일 진입점 활용
        initializeSegmentAndMuxerSync(null)
    }

    /**
     * Merges segments around an event timestamp using mp4parser and writes directly to MediaStore.
     */
    @RequiresApi(Build.VERSION_CODES.Q)
    suspend fun createEventClip(eventTimeMs: Long): String? = withContext(Dispatchers.IO) {
        val TAG = "SegmentedVideoRecorder"
        // 이벤트 전후 30초~10초 범위
        val fromMs = eventTimeMs - 30_000L
        val toMs   = eventTimeMs + 10_000L

        // DB에서 해당 범위 세그먼트 조회
        val segments = segmentRepo.querySegments(fromMs, toMs)
        Log.d(TAG, "querySegments -> ${segments.size} segs  [$fromMs,$toMs]")
        if (segments.isEmpty()) return@withContext null

        // 출력 파일 이름·메타 준비
        val sdf       = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US)
        val eventName = "${sdf.format(Date(eventTimeMs))}_event.mp4"
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, eventName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/AclickEvents")
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val outUri = context.contentResolver
            .insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: return@withContext null
        Log.d(TAG, "output uri = $outUri")

        // mp4parser로 트랙 수집
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

        // 합쳐진 Movie 객체 생성
        val result = Movie().apply {
            if (videoTracks.isNotEmpty()) addTrack(AppendTrack(*videoTracks.toTypedArray()))
            if (audioTracks.isNotEmpty()) addTrack(AppendTrack(*audioTracks.toTypedArray()))
        }
        val container = DefaultMp4Builder().build(result)

        // MediaStore에 쓰기
        context.contentResolver.openFileDescriptor(outUri, "rw")?.use { pfd ->
            FileOutputStream(pfd.fileDescriptor).channel.use { fc ->
                container.writeContainer(fc)
            }
        }

        // IS_PENDING 해제하여 갤러리에 노출
        values.clear()
        values.put(MediaStore.Video.Media.IS_PENDING, 0)
        context.contentResolver.update(outUri, values, null, null)

        Log.d(TAG, "merge done, uri=$outUri")
        return@withContext eventName
    }
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
     * 현재 세그먼트를 닫고 새 세그먼트를 생성하는 함수 (동기 버전)
     * recorderExecutor 내에서만 호출되어야 함
     */
    private fun rotateSegmentSync(endPtsUs: Long) {
        // 현재 뮤서 닫기
        closeSegmentSync(endPtsUs)
        // 새 세그먼트 생성
        openSegmentSync()
    }
    
    /**
     * 세그먼트 분할 조건 확인 유틸리티 함수
     */
    private fun shouldRotate(pts: Long, isKeyFrame: Boolean): Boolean {
        return pts - segmentStartTimeUs >= SEGMENT_DURATION_US && isKeyFrame
    }

    /**
     * 현재 세그먼트 뮤서 닫기 (동기 버전)
     */
    private fun closeSegmentSync(endPtsUs: Long) {
        try {
            muxer?.stop()
            
            // Q 이상에서 IS_PENDING 상태 해제
            currentSegment?.uri?.let { uri ->
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    val updateValues = ContentValues().apply {
                        put(MediaStore.Video.Media.IS_PENDING, 0)
                    }
                    try {
                        context.contentResolver.update(uri, updateValues, null, null)
                        Log.d(TAG, "Cleared IS_PENDING for URI: $uri")
                    } catch (e: android.database.sqlite.SQLiteConstraintException) {
                        // UNIQUE 제약 위반 시 무시
                        Log.w(TAG, "IS_PENDING update conflict for $uri – ignoring", e)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error clearing IS_PENDING for $uri", e)
                    }
                }
            }
            
            currentSegment = null
            muxer = null
            videoTrackIndex = -1
            
            currentSegment?.let { seg ->
                val durationMs = (endPtsUs - segmentStartTimeUs) / 1000
                // 세그먼트 업데이트는 IO 작업이므로 IO 전용 스레드로 처리
                ioExecutor.execute {
                    try {
                        // 비동기 작업이지만 suspend 함수를 실행해야 하므로 런블록킹 사용
                        kotlinx.coroutines.runBlocking {
                            segmentRepo.updateDuration(seg, durationMs)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating segment duration", e)
                    }
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
            }, handler
        )
    }

    /**
     * 리소스 해제 시작 (비동기)
     */
    private fun release() {
        // 모든 리소스 해제 작업을 recorderHandler에서 실행
        recorderHandler.post {
            releaseSync()
        }
    }

    /**
     * 리소스 해제 작업 동기 버전
     */
    private fun releaseSync() {
        try {
            // 인코더 종료 시그널 보내기
            encoder?.signalEndOfInputStream()

            // 현재 뮤서 정리
            if (muxer != null) {
                try {
                    closeSegmentSync(System.nanoTime() / 1000)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in final muxer cleanup", e)
                }
            }

            // 인코더 정리
            try {
                encoder?.stop()
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping encoder", e)
            }
            try {
                encoder?.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing encoder", e)
            }

            // 카메라 리소스 정리
            try {
                captureSession?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing capture session", e)
            }
            try {
                cameraDevice?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing camera device", e)
            }

            // 핸들러 정리 - 모든 메시지와 콜백 제거 후 정상 종료
            recorderHandler.removeCallbacksAndMessages(null)  // 모든 대기 콜백 제거
            recorderThread.quitSafely()                       // 핸들러 스레드 종료

            // Executor 정리
            ioExecutor.shutdown()

            Log.d(TAG, "Recorder resources fully released")
            _eventFlow.tryEmit(RecorderEvent.Stopped)
        } catch (e: Exception) {
            Log.e(TAG, "Error during recorder release", e)
            _eventFlow.tryEmit(RecorderEvent.Error(e, "Error during cleanup: ${e.message}"))
        }
    }
}
