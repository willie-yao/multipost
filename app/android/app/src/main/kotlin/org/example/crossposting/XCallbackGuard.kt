package org.example.crossposting

import java.net.URI
import java.net.URLDecoder

/** X-only target/expiry/replay boundary. AppAuth still owns random state and PKCE. */
internal class XCallbackGuard {
    private var target: String? = null
    private var startedAt = 0L

    @Synchronized fun prepare(configured: String, requested: String, now: Long): Boolean {
        if (target != null && now - startedAt in 0..600000L) return false
        if (configured.isEmpty() || configured != requested) return false
        val uri = runCatching { URI(configured) }.getOrNull() ?: return false
        if (!uri.isAbsolute || uri.rawQuery != null || uri.rawFragment != null || uri.rawUserInfo != null) return false
        target = configured
        startedAt = now
        return true
    }

    @Synchronized fun consume(configured: String, received: String, now: Long): Boolean {
        if (target != configured || now - startedAt !in 0..600000L) {
            clear()
            return false
        }
        val valid = runCatching {
            val expected = URI(configured)
            val uri = URI(received)
            val params = (uri.rawQuery ?: "").split('&').map { item ->
                val pair = item.split('=', limit = 2)
                URLDecoder.decode(pair[0], "UTF-8") to URLDecoder.decode(pair.getOrElse(1) { "" }, "UTF-8")
            }
            expected.scheme == uri.scheme && expected.rawAuthority == uri.rawAuthority &&
                expected.rawPath == uri.rawPath && uri.rawFragment == null &&
                params.count { it.first == "state" } == 1 &&
                params.single { it.first == "state" }.second.isNotEmpty() &&
                params.count { it.first == "code" || it.first == "error" } == 1 &&
                params.single { it.first == "code" || it.first == "error" }.second.isNotEmpty()
        }.getOrDefault(false)
        if (valid) clear()
        return valid
    }

    @Synchronized fun clear() { target = null }
}
