package com.example.iot

import android.net.Uri
import android.content.Context
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Build
import android.os.Environment
import android.content.ContentUris
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Represents a recorded video segment in MediaStore.
 */
data class Segment(
    val id: Long,
    val uri: Uri,
    val startMs: Long,
    val durationMs: Long
) {
    val endMs: Long get() = startMs + durationMs
}

/**
 * Defines operations to manage video segments.
 */
interface SegmentRepository {
    suspend fun insertSegment(fileName: String, startMs: Long): Segment?
    suspend fun updateDuration(segment: Segment, durationMs: Long)
    suspend fun querySegments(fromMs: Long, toMs: Long): List<Segment>
}

/**
 * MediaStore-based implementation of SegmentRepository.
 */
class MediaStoreSegmentRepository(
    private val context: Context
) : SegmentRepository {
    private val resolver = context.contentResolver

    override suspend fun insertSegment(originalFileName: String, startMs: Long): Segment? =
        withContext(Dispatchers.IO) {
            // 1) 준비
            val now = System.currentTimeMillis()
            val uniqueName = "${originalFileName}_${now}.mp4"

            // 2) ContentValues 구성
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, uniqueName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/Aclick"
                )
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
            put(MediaStore.Video.Media.DATE_TAKEN, now)
            put(MediaStore.Video.Media.DATE_ADDED, now / 1000)
        }

            // 3) 올바른 외장 볼륨 URI 선택
            val collectionUri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            } else {
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        }

            // 4) 삽입
            val insertedUri = resolver.insert(collectionUri, values) ?: return@withContext null

            // 5) 즉시 조회해서 _ID, 실제 파일 경로 확보
            var resultSegment: Segment? = null
            resolver.query(
                insertedUri,
                arrayOf(
                    MediaStore.Video.Media._ID,
                    MediaStore.Video.Media.DATA
                ),
                null,
                null,
                null
            )?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val id =
                        cursor.getLong(cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID))
                    val path =
                        cursor.getString(cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATA))
                    resultSegment = Segment(
                        id = id,
                        uri = insertedUri,
                        startMs = startMs,
                        durationMs = 0L,
                    )
                }
            }

            // 6) 조회 실패 시에도 최소한 ID 기반 Segment 반환
            resultSegment ?: Segment(
                id = ContentUris.parseId(insertedUri),
                uri = insertedUri,
                startMs = startMs,
                durationMs = 0L
            )
    }

    override suspend fun updateDuration(segment: Segment, durationMs: Long) {
        val cv = ContentValues().apply {
            put(MediaStore.Video.Media.DURATION, durationMs)
        }
        resolver.update(segment.uri, cv, null, null)
    }

    override suspend fun querySegments(fromMs: Long, toMs: Long): List<Segment> =
        withContext(Dispatchers.IO) {
            val toSec = (toMs / 1000).toString()
            val projection = arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DATE_ADDED,
                MediaStore.Video.Media.DURATION
            )
            val segmentsDesc = mutableListOf<Segment>()

            // 1) DESC 정렬, LIMIT 없이 전체 가져오기
            resolver.query(
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
                projection,
                "${MediaStore.Video.Media.DATE_ADDED} <= ?",
                arrayOf(toSec),
                "${MediaStore.Video.Media.DATE_ADDED} DESC"
            )?.use { cursor ->
                val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
                val dateIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
                val durIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
                while (cursor.moveToNext() && segmentsDesc.size < 4) {
                    val id = cursor.getLong(idIdx)
                    val uri = ContentUris.withAppendedId(
                        MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id
                    )
                    val date = cursor.getLong(dateIdx)
                    val dur = cursor.getLong(durIdx)
                    segmentsDesc += Segment(id, uri, date, dur)
                }
            }

            // 2) ASC 순으로 바꿔서 반환
            segmentsDesc
                .asReversed()   // DESC → ASC
        }
}