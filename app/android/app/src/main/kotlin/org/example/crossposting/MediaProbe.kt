package org.example.crossposting

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

/**
 * Video: metadata only (no frame decode, trimming or transcoding).
 * Photos: the platform decoder reads what the gallery shows (Ultra HDR, very
 * large camera files) with sampling, so a phone photo never needs a full-size
 * pixel buffer. Only app-private files are read; nothing is written.
 */
class MediaProbe(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val privateRoot = context.filesDir.canonicalFile
    private val channel = MethodChannel(messenger, "org.example.crossposting/media_probe")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        val mimeType = call.argument<String>("mimeType")
        when (call.method) {
            "inspect" -> {
                if (path == null || mimeType !in setOf("video/mp4", "video/quicktime", "video/webm")) {
                    result.error("invalid_media_request", "A supported private video is required.", null)
                    return
                }
                run(result, "media_metadata_unavailable", "Video metadata is unavailable. Replace or remove this item.") {
                    inspect(File(path), mimeType!!)
                }
            }
            "inspectPhoto" -> {
                if (path == null || mimeType !in photoTypes) {
                    result.error("invalid_media_request", "A supported private photo is required.", null)
                    return
                }
                run(result, "photo_unreadable", "This photo can't be read.") { inspectPhoto(File(path)) }
            }
            "fitPhoto" -> {
                val maxBytes = call.argument<Int>("maxBytes")
                val maxEdge = call.argument<Int>("maxEdge")
                if (path == null || mimeType !in photoTypes || maxBytes == null || maxBytes <= 0 ||
                    maxEdge == null || maxEdge <= 0) {
                    result.error("invalid_media_request", "A supported private photo is required.", null)
                    return
                }
                run(result, "photo_unfit", "This photo could not be made smaller.") {
                    fitPhoto(File(path), maxBytes, maxEdge)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun run(result: MethodChannel.Result, code: String, message: String, work: () -> Any) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (_: Throwable) {
                // OutOfMemoryError included: report, never crash the app.
                main.post { result.error(code, message, null) }
            }
        }
    }

    private fun privateFile(source: File): File {
        val file = source.canonicalFile
        require(file.path.startsWith(privateRoot.path + File.separator) && file.isFile && file.canRead()) {
            "Media must be a readable app-private file."
        }
        return file
    }

    private fun bounds(file: File): Pair<Int, Int> {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, options)
        require(options.outWidth > 0 && options.outHeight > 0) { "No photo bounds" }
        return options.outWidth to options.outHeight
    }

    private fun orientation(file: File): Int = try {
        ExifInterface(file.path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
    } catch (_: Exception) {
        ExifInterface.ORIENTATION_NORMAL
    }

    /** Largest power-of-two sample that keeps the long edge at least [edge]. */
    private fun sampleFor(width: Int, height: Int, edge: Int): Int {
        var sample = 1
        while (max(width, height) / (sample * 2) >= edge) sample *= 2
        return sample
    }

    private fun decode(file: File, sample: Int): Bitmap =
        BitmapFactory.decodeFile(file.path, BitmapFactory.Options().apply {
            inSampleSize = sample
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }) ?: error("Photo pixels could not be decoded")

    /** Display-oriented size; the pixels are decoded at a small sample to prove they are readable. */
    private fun inspectPhoto(source: File): Map<String, Any> {
        val file = privateFile(source)
        val (width, height) = bounds(file)
        decode(file, sampleFor(width, height, 512)).recycle()
        val swapped = orientation(file) in 5..8
        return mapOf("width" to if (swapped) height else width, "height" to if (swapped) width else height)
    }

    /** A display-oriented JPEG within [maxBytes]: long edge at most [maxEdge], no metadata, no transparency. */
    private fun fitPhoto(source: File, maxBytes: Int, maxEdge: Int): ByteArray {
        val file = privateFile(source)
        val (width, height) = bounds(file)
        val turn = orientationMatrix(orientation(file))
        for (edge in listOf(maxEdge, maxEdge * 4 / 5, maxEdge * 3 / 5, maxEdge / 2)) {
            val decoded = decode(file, sampleFor(width, height, edge))
            val scale = min(1f, edge.toFloat() / max(decoded.width, decoded.height))
            val matrix = Matrix(turn).apply { preScale(scale, scale) }
            val oriented = Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height, matrix, true)
            if (oriented !== decoded) decoded.recycle()
            val flat = Bitmap.createBitmap(oriented.width, oriented.height, Bitmap.Config.ARGB_8888)
            Canvas(flat).apply {
                drawColor(Color.WHITE)
                drawBitmap(oriented, 0f, 0f, Paint(Paint.FILTER_BITMAP_FLAG))
            }
            oriented.recycle()
            try {
                for (quality in listOf(90, 80, 70)) {
                    val out = ByteArrayOutputStream()
                    check(flat.compress(Bitmap.CompressFormat.JPEG, quality, out))
                    if (out.size() <= maxBytes) return out.toByteArray()
                }
            } finally {
                flat.recycle()
            }
        }
        error("Photo stays over the size limit")
    }

    private fun orientationMatrix(orientation: Int) = Matrix().apply {
        when (orientation) {
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> postScale(-1f, 1f)
            ExifInterface.ORIENTATION_ROTATE_180 -> postRotate(180f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL -> postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> { postRotate(90f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_90 -> postRotate(90f)
            ExifInterface.ORIENTATION_TRANSVERSE -> { postRotate(-90f); postScale(-1f, 1f) }
            ExifInterface.ORIENTATION_ROTATE_270 -> postRotate(-90f)
        }
    }

    private fun inspect(source: File, expectedMimeType: String): Map<String, Any> {
        val file = privateFile(source)
        val retriever = MediaMetadataRetriever()
        try {
            retriever.setDataSource(file.path)
            require(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes") { "No video track" }
            val actualMime = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_MIMETYPE)
            require(actualMime == expectedMimeType ||
                (expectedMimeType == "video/quicktime" && actualMime == "video/mp4")) { "Unexpected MIME=$actualMime expected=$expectedMimeType" }
            val width = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            val height = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
            val duration = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull()
            require(width != null && width > 0 && height != null && height > 0 && duration != null && duration > 0) { "Metadata width=$width height=$height duration=$duration" }
            val rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            require(rotation in setOf(0, 90, 180, 270))
            val swapped = rotation == 90 || rotation == 270
            return mapOf("width" to if (swapped) height else width,
                "height" to if (swapped) width else height, "durationMs" to duration)
        } finally {
            retriever.release()
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }

    private companion object {
        val photoTypes = setOf("image/jpeg", "image/png", "image/webp")
    }
}
