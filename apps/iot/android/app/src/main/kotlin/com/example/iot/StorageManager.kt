package com.example.iot

import android.content.Context
import android.os.StatFs
import android.util.Log
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

/**
 * 저장 공간 관리 클래스
 * - 세그먼트 파일의 총 크기 관리
 * - 저장 공간 모니터링
 * - 용량 초과 시 오래된 파일 삭제
 */
class StorageManager(
    private val context: Context,
    private val segmentManager: VideoSegmentManager
) {
    companion object {
        private const val TAG = "StorageManager"
        private const val MAX_STORAGE_SIZE_BYTES = 40L * 1024 * 1024 * 1024 // 32GB
        private const val CLEANUP_INTERVAL_MS = 60000L // 1분
    }
    
    private val segmentDirectory = File(context.getExternalFilesDir(null), "video_segments")
    private lateinit var cleanupExecutor: ScheduledExecutorService
    
    /**
     * 모니터링 시작
     */
    fun startMonitoring() {
        cleanupExecutor = Executors.newSingleThreadScheduledExecutor()
        cleanupExecutor.scheduleAtFixedRate({
            try {
                checkAndCleanupStorage()
            } catch (e: Exception) {
                Log.e(TAG, "저장소 정리 오류", e)
            }
        }, CLEANUP_INTERVAL_MS, CLEANUP_INTERVAL_MS, TimeUnit.MILLISECONDS)
        
        Log.d(TAG, "저장소 모니터링 시작됨")
    }
    
    /**
     * 모니터링 중지
     */
    fun stopMonitoring() {
        if (::cleanupExecutor.isInitialized) {
            cleanupExecutor.shutdownNow()
        }
        Log.d(TAG, "저장소 모니터링 중지됨")
    }
    
    /**
     * 저장공간 확인 및 정리
     */
    fun checkAndCleanupStorage() {
        val totalSize = calculateSegmentsSize()
        Log.d(TAG, "현재 세그먼트 총 크기: ${totalSize / (1024 * 1024)}MB")
        
        if (totalSize > MAX_STORAGE_SIZE_BYTES) {
            Log.w(TAG, "저장 공간 한도 초과: ${totalSize / (1024 * 1024)}MB > ${MAX_STORAGE_SIZE_BYTES / (1024 * 1024)}MB")
            // 90%까지 줄이기
            deleteOldestSegmentsUntilSize(MAX_STORAGE_SIZE_BYTES * 0.9)
        }
    }
    
    /**
     * 세그먼트 총 크기 계산
     */
    private fun calculateSegmentsSize(): Long {
        var totalSize = 0L
        segmentDirectory.listFiles()?.forEach { file ->
            if (file.isFile) {
                totalSize += file.length()
            }
        }
        return totalSize
    }
    
    /**
     * 오래된 세그먼트 삭제
     */
    private fun deleteOldestSegmentsUntilSize(targetSize: Double) {
        val files = segmentDirectory.listFiles()?.filter { it.isFile }?.sortedBy { it.lastModified() }
        
        var currentSize = calculateSegmentsSize()
        var deletedCount = 0
        var i = 0
        
        while (currentSize > targetSize && files != null && i < files.size) {
            val file = files[i]
            val fileSize = file.length()
            
            if (file.delete()) {
                currentSize -= fileSize
                deletedCount++
                Log.d(TAG, "오래된 세그먼트 삭제됨: ${file.name}, 크기: ${fileSize / 1024}KB")
            }
            
            i++
        }
        
        Log.d(TAG, "총 $deletedCount 개의 세그먼트 삭제됨, 현재 크기: ${currentSize / (1024 * 1024)}MB")
    }
    
    /**
     * 상태 정보 반환
     */
    fun getStatus(): Map<String, Any> {
        val totalSize = calculateSegmentsSize()
        val availableSpace = getAvailableStorageSpace()
        val segmentCount = segmentDirectory.listFiles()?.filter { it.isFile }?.size ?: 0
        
        return mapOf(
            "totalSegmentSizeMB" to (totalSize / (1024 * 1024)),
            "availableSpaceMB" to (availableSpace / (1024 * 1024)),
            "segmentCount" to segmentCount,
            "maxStorageSizeMB" to (MAX_STORAGE_SIZE_BYTES / (1024 * 1024))
        )
    }
    
    /**
     * 사용 가능한 저장공간 확인
     */
    fun getAvailableStorageSpace(): Long {
        val stats = StatFs(context.getExternalFilesDir(null)?.path)
        return stats.availableBlocksLong * stats.blockSizeLong
    }
}
