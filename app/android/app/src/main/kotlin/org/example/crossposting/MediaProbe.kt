package org.example.crossposting

import android.content.Context
import android.media.MediaMetadataRetriever
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Metadata only: no video byte buffer, frame decode, trimming or transcoding. */
class MediaProbe(context: Context, messenger: BinaryMessenger) : MethodChannel.MethodCallHandler {
    private val privateRoot = context.filesDir.canonicalFile
    private val channel = MethodChannel(messenger, "org.example.crossposting/media_probe")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "inspect") {
            result.notImplemented()
            return
        }
        val path = call.argument<String>("path")
        val mimeType = call.argument<String>("mimeType")
        if (path == null || mimeType !in setOf("video/mp4", "video/quicktime", "video/webm")) {
            result.error("invalid_media_request", "A supported private video is required.", null)
            return
        }
        worker.execute {
            try {
                val metadata = inspect(File(path), mimeType!!)
                main.post { result.success(metadata) }
            } catch (_: Exception) {
                main.post {
                    result.error("media_metadata_unavailable", "Video metadata is unavailable. Replace or remove this item.", null)
                }
            }
        }
    }

    private fun inspect(source: File, expectedMimeType: String): Map<String, Any> {
        val file = source.canonicalFile
        require(file.path.startsWith(privateRoot.path + File.separator) && file.isFile && file.canRead()) {
            "Video must be a readable app-private file."
        }
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
}
