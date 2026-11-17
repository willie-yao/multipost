package org.example.crossposting

import android.content.ContentResolver
import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.util.concurrent.Executors

/** Per-job scoped MediaStore work. Never queries, edits or deletes unrelated media. */
class MediaExporter(context: Context, messenger: BinaryMessenger, private val instagram: InstagramTransfer) : MethodChannel.MethodCallHandler {
    private val files = PreparedPhotoFiles(context)
    private val resolver = context.contentResolver
    private val owner = context.packageName
    private val collection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
    private val channel = MethodChannel(messenger, "crossposting/instagram")
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val uuid = "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
    private val relativePath = "Pictures/CrossPosting/"

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "openInstagram") {
            instagram.open(result)
            return
        }
        if (call.method != "savePhoto" && call.method != "reconcilePhoto" && call.method != "sharePhotos") {
            result.notImplemented()
            return
        }
        worker.execute {
            try {
                if (call.method == "sharePhotos") {
                    val intent = instagram.prepareShare(call)
                    main.post { instagram.dispatch(intent, result) }
                    return@execute
                }
                val request = request(call)
                val existing = reconcile(request)
                val uri = existing ?: if (call.method == "savePhoto") save(request) else null
                main.post { result.success(if (uri == null) emptyMap<String, String>() else mapOf("uri" to uri.toString())) }
            } catch (_: IllegalArgumentException) {
                main.post { result.error(if (call.method == "sharePhotos") "invalid-share" else "invalid-export", "Valid prepared photos and operation details are required.", null) }
            } catch (_: SecurityException) {
                main.post { result.error("access-revoked", "This app cannot access that saved photo. Check gallery access and retry.", null) }
            } catch (_: Exception) {
                main.post { result.error(if (call.method == "sharePhotos") "share-unavailable" else "export-unavailable", "Prepared photos could not be transferred or checked. Keep the package and try again.", null) }
            }
        }
    }

    private data class Request(val source: File, val displayName: String, val mimeType: String, val hash: String, val receipt: Uri?)

    private fun request(call: MethodCall): Request {
        val jobId = call.argument<String>("jobId") ?: throw IllegalArgumentException()
        val sourcePath = call.argument<String>("sourcePath") ?: throw IllegalArgumentException()
        val displayName = call.argument<String>("displayName") ?: throw IllegalArgumentException()
        val mimeType = call.argument<String>("mimeType") ?: throw IllegalArgumentException()
        val hash = call.argument<String>("expectedHash") ?: throw IllegalArgumentException()
        require(Regex("^$uuid$").matches(jobId))
        val file = files.file(sourcePath, mimeType, hash)
        val ordinal = file.name.substringBefore('.')
        val extension = file.extension
        require(displayName == "caption-$jobId-$ordinal.$extension")
        val receipt = call.argument<String>("uri")?.let { value ->
            val uri = Uri.parse(value)
            val id = uri.lastPathSegment?.toLongOrNull() ?: throw IllegalArgumentException()
            // Accept only this exporter's canonical primary-volume image item URIs.
            // Equality also rejects alternate authorities, queries, fragments and encodings.
            require(id > 0 && uri == ContentUris.withAppendedId(collection, id))
            uri
        }
        return Request(file, displayName, mimeType, hash, receipt)
    }

    private data class Row(val uri: Uri, val pending: Boolean)

    private fun rows(request: Request): List<Row> {
        val projection = arrayOf(MediaStore.Images.Media._ID, MediaStore.Images.Media.IS_PENDING,
            MediaStore.Images.Media.DISPLAY_NAME, MediaStore.Images.Media.RELATIVE_PATH,
            MediaStore.Images.Media.OWNER_PACKAGE_NAME)
        // A stored item URI remains stable when the user renames/moves a photo.
        // Generated metadata identifies only no-receipt crash-recovery rows.
        val target = request.receipt ?: collection
        val selection = if (request.receipt == null)
            "${MediaStore.Images.Media.DISPLAY_NAME} = ? AND ${MediaStore.Images.Media.RELATIVE_PATH} = ? AND ${MediaStore.Images.Media.OWNER_PACKAGE_NAME} = ?"
            else null
        val args = if (request.receipt == null) arrayOf(request.displayName, relativePath, owner) else null
        val cursor = if (Build.VERSION.SDK_INT >= 30) {
            resolver.query(target, projection, Bundle().apply {
                if (selection != null) {
                    putString(ContentResolver.QUERY_ARG_SQL_SELECTION, selection)
                    putStringArray(ContentResolver.QUERY_ARG_SQL_SELECTION_ARGS, args)
                }
                putInt(MediaStore.QUERY_ARG_MATCH_PENDING, MediaStore.MATCH_INCLUDE)
                putInt(MediaStore.QUERY_ARG_MATCH_TRASHED, MediaStore.MATCH_EXCLUDE)
            }, null)
        } else {
            @Suppress("DEPRECATION")
            val includingPending = MediaStore.setIncludePending(target)
            resolver.query(includingPending, projection, selection, args, null)
        } ?: throw IOException("Media provider unavailable")
        return cursor.use {
            val result = mutableListOf<Row>()
            while (it.moveToNext()) {
                // Verify ownership before any byte read/update/delete. Mutable
                // display name/folder are not identity for a durable receipt.
                val uri = ContentUris.withAppendedId(collection, it.getLong(0))
                require(it.getString(4) == owner)
                if (request.receipt != null) {
                    require(uri == request.receipt)
                } else {
                    require(it.getString(2) == request.displayName && it.getString(3) == relativePath)
                }
                result.add(Row(uri, it.getInt(1) == 1))
            }
            result
        }
    }

    /** Resume can finish verified bytes or remove incomplete pending bytes; never creates a row. */
    private fun reconcile(request: Request): Uri? {
        var complete: Uri? = null
        for (row in rows(request)) {
            val input = resolver.openInputStream(row.uri) ?: throw IOException("Media stream unavailable")
            val matches = files.hash(input) == request.hash
            if (matches) {
                if (complete != null) throw IOException("Multiple completed rows require recovery")
                if (row.pending) publish(row.uri)
                complete = row.uri
            } else if (row.pending) {
                if (resolver.delete(row.uri, null, null) != 1) throw IOException("Incomplete row could not be removed")
            } else {
                // A user may have edited a visible gallery image; preserve it.
                throw IOException("Saved photo changed")
            }
        }
        return complete
    }

    private fun publish(uri: Uri) {
        val count = resolver.update(uri, ContentValues().apply {
            put(MediaStore.Images.Media.IS_PENDING, 0)
        }, null, null)
        if (count != 1) throw IOException("Photo was not committed")
    }

    private fun save(request: Request): Uri {
        files.verify(request.source, request.hash)
        val uri = resolver.insert(collection, ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, request.displayName)
            put(MediaStore.Images.Media.MIME_TYPE, request.mimeType)
            put(MediaStore.Images.Media.RELATIVE_PATH, relativePath)
            put(MediaStore.Images.Media.IS_PENDING, 1)
        }) ?: throw IOException("Could not create gallery item")
        try {
            val output = resolver.openOutputStream(uri, "w") ?: throw IOException("Media stream unavailable")
            output.use {
                request.source.inputStream().use { input -> input.copyTo(it) }
                it.flush()
            }
            val written = resolver.openInputStream(uri) ?: throw IOException("Media stream unavailable")
            if (files.hash(written) != request.hash) throw IOException("Photo write incomplete")
            publish(uri)
            return uri
        } catch (error: Exception) {
            try { resolver.delete(uri, null, null) } catch (_: Exception) { /* Exact pending row remains recoverable. */ }
            throw error
        }
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        worker.shutdown()
    }
}
