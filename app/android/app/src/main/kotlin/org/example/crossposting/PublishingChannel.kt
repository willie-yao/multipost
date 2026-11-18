package org.example.crossposting

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Explicit calls only: no network listener, browser callback, or send boundary. */
class PublishingChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "crossposting/publishing")
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "networkAvailability" -> {
                    try {
                        val manager = activity.getSystemService(ConnectivityManager::class.java)
                        val network = manager?.activeNetwork
                        val capabilities = network?.let { manager.getNetworkCapabilities(it) }
                        result.success(when {
                            manager == null -> null
                            network == null -> false
                            capabilities == null -> null
                            capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
                                capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED) -> true
                            else -> null
                        })
                    } catch (_: Exception) { result.success(null) }
                }
                "openOfficialUrl" -> {
                    val uri = (call.arguments as? String)?.let { Uri.parse(it) }
                    if (uri == null || !officialUrl(uri)) {
                        result.success(false)
                    } else {
                        try {
                            openPost(uri)
                            result.success(true)
                        } catch (_: Exception) { result.success(false) }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    fun dispose() { channel.setMethodCallHandler(null) }

    /**
     * The destination's own app when it is installed; otherwise an in-app
     * browser tab on top of this app, so Back and its close button return here.
     * A full browser would open in its own task and keep Back for its history.
     */
    private fun openPost(uri: Uri) {
        val view = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            try {
                activity.startActivity(Intent(view).addFlags(Intent.FLAG_ACTIVITY_REQUIRE_NON_BROWSER))
                return
            } catch (_: ActivityNotFoundException) {
                // No destination app; use the in-app tab below.
            }
        }
        CustomTabsIntent.Builder().setShowTitle(true).build().launchUrl(activity, uri)
    }

    private fun officialUrl(uri: Uri): Boolean {
        if (uri.scheme != "https" || uri.userInfo != null || uri.port != -1 || uri.query != null || uri.fragment != null) return false
        val path = uri.path ?: return false
        return when (uri.host) {
            "x.com" -> Regex("^/i/status/[1-9][0-9]*$").matches(path) ||
                Regex("^/[A-Za-z0-9_]{1,15}$").matches(path) &&
                path.drop(1).lowercase() !in setOf("intent", "settings", "home", "compose", "search", "login", "logout", "i")
            "bsky.app" -> Regex("^/profile/(?:did:plc:[a-z2-7]{24}|[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?\\.[a-zA-Z]{2,})(?:/post/[234567abcdefghijklmnopqrstuvwxyz]{13})?$").matches(path)
            else -> false
        }
    }
}
