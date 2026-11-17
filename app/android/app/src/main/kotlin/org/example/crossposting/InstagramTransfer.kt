package org.example.crossposting

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Explicit user actions only. An accepted intent is never publication proof. */
class InstagramTransfer(private val activity: Activity) {
    private val files = PreparedPhotoFiles(activity)
    private val instagram = "com.instagram.android"

    fun open(result: MethodChannel.Result) {
        try {
            val intent = activity.packageManager.getLaunchIntentForPackage(instagram)
            if (intent == null) {
                result.success("unavailable")
                return
            }
            activity.startActivity(intent)
            result.success("opened")
        } catch (_: ActivityNotFoundException) {
            result.success("unavailable")
        } catch (_: Exception) {
            result.success("failed")
        }
    }

    /** Called on the existing channel worker; all path/hash/URI IO stays off main. */
    fun prepareShare(call: MethodCall): Intent? {
        if (call.argument<Boolean>("supported") != true) return null
        val packageId = call.argument<String>("packageId") ?: throw IllegalArgumentException()
        val photos = call.argument<List<Map<String, Any>>>("photos") ?: throw IllegalArgumentException()
        require(photos.size in 1..20)
        val mimeTypes = mutableSetOf<String>()
        val uris = ArrayList<android.net.Uri>()
        for ((index, photo) in photos.withIndex()) {
            val path = photo["sourcePath"] as? String ?: throw IllegalArgumentException()
            val mime = photo["mimeType"] as? String ?: throw IllegalArgumentException()
            val hash = photo["expectedHash"] as? String ?: throw IllegalArgumentException()
            val file = files.file(path, mime, hash)
            require(file.parentFile?.name == packageId)
            require(file.nameWithoutExtension == (index + 1).toString().padStart(2, '0'))
            files.verify(file, hash)
            mimeTypes.add(mime)
            uris.add(FileProvider.getUriForFile(activity, "${activity.packageName}.instagram-files", file))
        }
        return Intent(if (uris.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE).apply {
            setPackage(instagram)
            type = if (mimeTypes.size == 1) mimeTypes.single() else "image/*"
            if (uris.size == 1) putExtra(Intent.EXTRA_STREAM, uris.single())
            else putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            clipData = ClipData.newUri(activity.contentResolver, "Prepared photos", uris.first()).apply {
                for (uri in uris.drop(1)) addItem(ClipData.Item(uri))
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            // Caption and descriptions remain separate user copy/paste actions.
        }
    }

    /** Main-thread activity work. No chooser target is guessed or promoted. */
    fun dispatch(intent: Intent?, result: MethodChannel.Result) {
        try {
            if (intent == null || intent.resolveActivity(activity.packageManager) == null) {
                result.success(mapOf("status" to "unavailable"))
                return
            }
            activity.startActivity(intent)
            result.success(mapOf("status" to "dispatchedToInstagram", "targetPackage" to instagram))
        } catch (_: ActivityNotFoundException) {
            result.success(mapOf("status" to "unavailable"))
        } catch (_: Exception) {
            result.success(mapOf("status" to "failed"))
        }
        // Do not revoke URI grants or delete prepared files when this app resumes.
    }
}
