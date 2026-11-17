package org.example.crossposting

import android.content.Context
import android.os.SystemClock
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.security.MessageDigest

/** Feature-owned bridge: package disk durability and the single pending X callback. */
internal class AccountsChannel(context: Context, private val engine: FlutterEngine) {
    private val messenger = engine.dartExecutor.binaryMessenger
    private val appContext = context.applicationContext
    private val channel = MethodChannel(messenger, "crossposting/accounts",
        StandardMethodCodec.INSTANCE, messenger.makeBackgroundTaskQueue())

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "commitCredentials" -> {
                        // flutter_secure_storage 11.2.0 uses apply() for ciphertext and
                        // wrapped keys. commit() waits for preceding applies in each file.
                        // These three artifacts belong to ONE fixed package namespace.
                        val namespace = when (call.arguments as? String) {
                            "x" -> "caption_x_credentials"
                            "bluesky" -> "caption_bluesky_credentials"
                            else -> throw IllegalArgumentException()
                        }
                        val names = listOf("FlutterSecureKeyStorage:$namespace",
                            "FlutterSecureStorageConfiguration:$namespace", namespace)
                        result.success(names.all { name ->
                            appContext.getSharedPreferences(name, Context.MODE_PRIVATE).edit().commit()
                        })
                    }
                    "reinitializeCredentialStorage" -> {
                        // Official plugin lifecycle clears cached resetOnError/ciphers.
                        // Dart's private vault-wide queue guarantees no package call overlaps.
                        Handler(Looper.getMainLooper()).post {
                            try {
                                engine.plugins.remove(FlutterSecureStoragePlugin::class.java)
                                engine.plugins.add(FlutterSecureStoragePlugin())
                                result.success(true)
                            } catch (_: Exception) {
                                result.error("accounts_unavailable", "Account storage is unavailable.", null)
                            }
                        }
                    }
                    "prepareBlueskyAuthorization" -> {
                        val configured = BuildConfig.CAPTION_BLUESKY_REDIRECT_URI
                        result.success(configured.isNotEmpty() && call.arguments == configured)
                    }
                    "prepareXAuthorization" -> {
                        // AppAuth otherwise falls back to plain PKCE if SHA-256 is absent.
                        MessageDigest.getInstance("SHA-256")
                        result.success(callbackGuard.prepare(BuildConfig.CAPTION_X_REDIRECT_URI,
                            call.arguments as? String ?: "", SystemClock.elapsedRealtime()))
                    }
                    "finishXAuthorization" -> { callbackGuard.clear(); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("accounts_unavailable", "Account storage or setup is unavailable.", null)
            }
        }
    }

    fun dispose() { channel.setMethodCallHandler(null) }
    companion object { val callbackGuard = XCallbackGuard() }
}
