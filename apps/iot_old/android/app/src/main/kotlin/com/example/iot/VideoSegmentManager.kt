package com.example.iot

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.text.SimpleDateFormat
import java.util.Date
import java.util.LinkedList
import java.util.Locale
import kotlin.math.abs

/**
 * 비디오 세그먼트 관리 클래스
 * - 세그먼트 파일 생성 및 관리
 * - fsync 수행
 * - 세그먼트 검색 및 병합
 */
class VideoSegmentManager(private val context: Context) {
    companion object {
        private const val TAG = "VideoSegmentManager"
        private const val MAX_SEGMENTS_TO_KEEP = 1000 // 최대 유지할 세그먼트 수
    }
    
    private val segmentDirectory: File
    private val segments = LinkedList<File>()
    private var currentSegmentFileDescriptor: FileDescriptor? = null
    private var currentFileOutputStream: FileOutputStream? = null
    
    init {
        // 세그먼트 저장 디렉토리 초기화
        segmentDirectory = File(context.getExternalFilesDir(null), "video_segments")
        if (!segmentDirectory.exists()) {
            segmentDirectory.mkdirs()
        }
        
        // 기존 세그먼트 파일 로드
        loadExistingSegments()
    }
    
    /**
     * 새 세그먼트 파일 생성
     */
    fun createNewSegmentFile(timestamp: Long): File {
        // 기존 파일 디스크립터 닫기
        closeCurrentFileDescriptor()
        
        // 타임스탬프 기반 파일명 생성
        val dateFormat = SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault())
        val timeString = dateFormat.format(Date(timestamp))
        val segmentFile = File(segmentDirectory, "${timeString}_10s.mp4")
        
        // 세그먼트 목록에 추가
        segments.add(segmentFile)
        
        // 최대 세그먼트 수 제한
        while (segments.size > MAX_SEGMENTS_TO_KEEP) {
            val oldestSegment = segments.removeFirst()
            oldestSegment.delete()
            Log.d(TAG, "최대 세그먼트 수 초과로 삭제: ${oldestSegment.name}")
        }
        
        // 파일 디스크립터 열기 (fsync 용)
        try {
            currentFileOutputStream = FileOutputStream(segmentFile)
            currentSegmentFileDescriptor = currentFileOutputStream?.fd
        } catch (e: Exception) {
            Log.e(TAG, "파일 디스크립터 열기 실패", e)
        }
        
        return segmentFile
    }
    
    /**
     * fsync 수행
     */
    fun performFsync() {
        try {
            currentSegmentFileDescriptor?.sync()
        } catch (e: Exception) {
            Log.e(TAG, "fsync 실패", e)
        }
    }
    
    /**
     * 현재 파일 디스크립터 닫기
     */
    private fun closeCurrentFileDescriptor() {
        try {
            currentFileOutputStream?.close()
            currentFileOutputStream = null
            currentSegmentFileDescriptor = null
        } catch (e: Exception) {
            Log.e(TAG, "파일 디스크립터 닫기 실패", e)
        }
    }
    
    /**
     * 기존 세그먼트 파일 로드
     */
    private fun loadExistingSegments() {
        val files = segmentDirectory.listFiles { file ->
            file.isFile && file.name.endsWith(".mp4")
        }
        
        files?.sortBy { it.lastModified() }
        files?.forEach { segments.add(it) }
        
        Log.d(TAG, "기존 세그먼트 ${segments.size}개 로드됨")
    }
    
    /**
     * 특정 시간 주변 세그먼트 가져오기
     * @param time 기준 시간
     * @param beforeCount 이전 세그먼트 수
     * @param afterCount 이후 세그먼트 수
     */
    fun getSegmentsAroundTime(time: Long, beforeCount: Int, afterCount: Int): List<File> {
        // 주어진 시간에 가장 가까운 세그먼트 찾기
        val closestSegment = segments.minByOrNull { abs(it.lastModified() - time) } ?: return emptyList()
        val closestIndex = segments.indexOf(closestSegment)
        
        val result = mutableListOf<File>()
        
        // 이전 세그먼트
        for (i in (closestIndex - beforeCount).coerceAtLeast(0) until closestIndex) {
            result.add(segments[i])
        }
        
        // 현재 세그먼트
        result.add(closestSegment)
        
        // 이후 세그먼트
        for (i in (closestIndex + 1)..((closestIndex + afterCount).coerceAtMost(segments.size - 1))) {
            result.add(segments[i])
        }
        
        return result
    }
    
    /**
     * 세그먼트 병합
     * @param segmentFiles 병합할 세그먼트 파일 목록
     * @param outputPath 출력 파일 경로
     */
    fun combineSegments(segmentFiles: List<File>, outputPath: String): String {
        if (segmentFiles.isEmpty()) {
            throw RuntimeException("병합할 세그먼트가 없습니다")
        }
        
        Log.d(TAG, "세그먼트 병합 시작: ${segmentFiles.size}개 세그먼트")
        
        // MediaMuxer 설정
        val mediaMuxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var audioTrackIndex = -1
        var videoTrackIndex = -1
        
        try {
            // 첫 번째 세그먼트에서 포맷 정보 가져오기
            val firstExtractor = MediaExtractor()
            firstExtractor.setDataSource(segmentFiles[0].absolutePath)
            
            // 트랙 정보 찾기
            val trackCount = firstExtractor.trackCount
            var audioFormat: MediaFormat? = null
            var videoFormat: MediaFormat? = null
            
            for (i in 0 until trackCount) {
                val format = firstExtractor.getTrackFormat(i)
                val mime = format.getString(MediaFormat.KEY_MIME)
                
                if (mime?.startsWith("video/") == true) {
                    videoFormat = format
                } else if (mime?.startsWith("audio/") == true) {
                    audioFormat = format
                }
            }
            
            firstExtractor.release()
            
            // MediaMuxer 트랙 추가
            if (videoFormat != null) {
                videoTrackIndex = mediaMuxer.addTrack(videoFormat)
            }
            
            if (audioFormat != null) {
                audioTrackIndex = mediaMuxer.addTrack(audioFormat)
            }
            
            // MediaMuxer 시작
            mediaMuxer.start()
            
            // 각 세그먼트 처리
            for (segmentFile in segmentFiles) {
                processSegment(segmentFile, mediaMuxer, videoTrackIndex, audioTrackIndex)
            }
            
            // MediaMuxer 종료
            mediaMuxer.stop()
            mediaMuxer.release()
            
            Log.d(TAG, "세그먼트 병합 완료: $outputPath")
            return outputPath
            
        } catch (e: Exception) {
            Log.e(TAG, "세그먼트 병합 실패", e)
            mediaMuxer.release()
            File(outputPath).delete()
            throw RuntimeException("세그먼트 병합 실패: ${e.message}")
        }
    }
    
    /**
     * 개별 세그먼트 처리
     */
    private fun processSegment(segmentFile: File, mediaMuxer: MediaMuxer, videoTrackIndex: Int, audioTrackIndex: Int) {
        val extractor = MediaExtractor()
        extractor.setDataSource(segmentFile.absolutePath)
        
        val buffer = ByteBuffer.allocate(1024 * 1024) // 1MB 버퍼
        val bufferInfo = MediaCodec.BufferInfo()
        
        // 비디오 트랙 처리
        if (videoTrackIndex >= 0) {
            processTrack(extractor, mediaMuxer, buffer, bufferInfo, "video/", videoTrackIndex)
        }
        
        // 오디오 트랙 처리
        if (audioTrackIndex >= 0) {
            processTrack(extractor, mediaMuxer, buffer, bufferInfo, "audio/", audioTrackIndex)
        }
        
        extractor.release()
    }
    
    /**
     * 특정 트랙 처리
     */
    private fun processTrack(extractor: MediaExtractor, mediaMuxer: MediaMuxer, buffer: ByteBuffer, 
                           bufferInfo: MediaCodec.BufferInfo, mimePrefix: String, trackIndex: Int) {
        // 해당 타입의 트랙 찾기
        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME)
            
            if (mime?.startsWith(mimePrefix) == true) {
                extractor.selectTrack(i)
                
                // 샘플 읽기 및 쓰기
                while (true) {
                    val sampleSize = extractor.readSampleData(buffer, 0)
                    if (sampleSize < 0) break
                    
                    bufferInfo.size = sampleSize
                    bufferInfo.offset = 0
                    bufferInfo.flags = extractor.sampleFlags
                    bufferInfo.presentationTimeUs = extractor.sampleTime
                    
                    mediaMuxer.writeSampleData(trackIndex, buffer, bufferInfo)
                    extractor.advance()
                }
                
                extractor.unselectTrack(i)
                break
            }
        }
    }
    fun createEventClip(): String {
        return ""
    }

    
    /**
     * 모든 세그먼트 파일 목록 가져오기
     */
    fun getAllSegments(): List<File> {
        return segments.toList()
    }
    
    /**
     * 정리 작업
     */
    fun cleanup() {
        closeCurrentFileDescriptor()
    }
}
