package org.example.crossposting

import android.content.Context
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.security.MessageDigest

/** Feature-owned bridge: package disk durability and the single pending X callback. */
internal class AccountsChannel(context: Context, messenger: BinaryMessenger) {
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
                        val names = listOf("FlutterSecureKeyStorage:caption_credentials",
                            "FlutterSecureStorageConfiguration:caption_credentials", "caption_credentials")
                        result.success(names.all { name ->
                            appContext.getSharedPreferences(name, Context.MODE_PRIVATE).edit().commit()
                        })
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
