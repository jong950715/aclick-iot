package com.example.iot

import android.net.Uri
import android.content.Context
import android.content.ContentValues
import android.provider.MediaStore
import android.os.Build
import android.os.Environment
import android.content.ContentUris

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

    override suspend fun insertSegment(fileName: String, startMs: Long): Segment? {
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Video.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_MOVIES}/Aclick"
                )
            }
        }
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: return null
        val id = ContentUris.parseId(uri)
        return Segment(id, uri, startMs, durationMs = 0L)
    }

    override suspend fun updateDuration(segment: Segment, durationMs: Long) {
        val cv = ContentValues().apply {
            put(MediaStore.Video.Media.DURATION, durationMs)
        }
        resolver.update(segment.uri, cv, null, null)
    }

    override suspend fun querySegments(fromMs: Long, toMs: Long): List<Segment> {
        val fromSec = (fromMs / 1000).toString()
        val toSec   = (toMs   / 1000).toString()
        val sel = "${MediaStore.Video.Media.DATE_ADDED} BETWEEN ? AND ?"
        val args = arrayOf(fromSec, toSec)
        val sort = "${MediaStore.Video.Media.DATE_ADDED} ASC"
        val list = mutableListOf<Segment>()

        resolver.query(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DATE_ADDED,
                MediaStore.Video.Media.DURATION
            ),
            sel, args, sort
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media._ID)
            val startIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DATE_ADDED)
            val durIdx = cursor.getColumnIndexOrThrow(MediaStore.Video.Media.DURATION)
            while (cursor.moveToNext()) {
                val id = cursor.getLong(idIdx)
                val uri = ContentUris.withAppendedId(
                    MediaStore.Video.Media.EXTERNAL_CONTENT_URI, id
                )
                val start = cursor.getLong(startIdx)
                val dur = cursor.getLong(durIdx)
                list += Segment(id, uri, start, dur)
            }
        }
        return list
    }
}