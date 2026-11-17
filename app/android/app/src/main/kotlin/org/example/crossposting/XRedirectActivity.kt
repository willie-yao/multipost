package org.example.crossposting

import android.app.Activity
import android.os.Bundle
import android.os.SystemClock
import net.openid.appauth.AuthorizationManagementActivity

/** Rejects invalid targets before AppAuth; never records the callback URI. */
class XRedirectActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val received = intent?.data
        if (received != null && AccountsChannel.callbackGuard.consume(
                BuildConfig.CAPTION_X_REDIRECT_URI, received.toString(), SystemClock.elapsedRealtime())) {
            startActivity(AuthorizationManagementActivity.createResponseHandlingIntent(this, received))
        }
        finish()
    }
}
