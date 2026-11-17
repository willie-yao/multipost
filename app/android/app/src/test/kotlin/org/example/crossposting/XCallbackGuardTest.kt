package org.example.crossposting

import org.junit.Assert.*
import org.junit.Test

class XCallbackGuardTest {
    private val target = "com.example.caption:/x"

    @Test fun exactTargetAllowsOAuthQueryOnce() {
        val guard = XCallbackGuard()
        assertTrue(guard.prepare(target, target, 1000))
        assertTrue(guard.consume(target, "$target?code=opaque&state=random", 1001))
        assertFalse(guard.consume(target, "$target?code=opaque&state=random", 1002))
    }

    @Test fun wrongTargetsAndAmbiguousQueriesCannotConsumeFlow() {
        val invalid = listOf(
            "com.other.caption:/x?code=a&state=b", "com.example.caption:/wrong?code=a&state=b",
            "com.example.caption://host/x?code=a&state=b", "$target?code=a&state=b#fragment",
            "$target?code=a&state=b&state=c", "$target?code=a&%73tate=b&state=c",
            "$target?code=a&code=b&state=c", "$target?code=a&error=denied&state=c",
            "$target?code=a", "$target?state=b", "$target?code=a&state=",
        )
        for (callback in invalid) {
            val guard = XCallbackGuard()
            assertTrue(guard.prepare(target, target, 1000))
            assertFalse(callback, guard.consume(target, callback, 1001))
            assertTrue(guard.consume(target, "$target?code=a&state=b", 1002))
        }
    }

    @Test fun httpsRequiresExactAuthorityPortAndEncodedPath() {
        val target = "https://app.example.com/x"
        val guard = XCallbackGuard()
        assertTrue(guard.prepare(target, target, 0))
        for (wrong in listOf("https://other.example.com/x", "https://app.example.com:443/x",
            "https://user@app.example.com/x", "https://app.example.com/%78")) {
            assertFalse(guard.consume(target, "$wrong?code=a&state=b", 1))
        }
        assertTrue(guard.consume(target, "$target?code=a&state=b", 2))
    }

    @Test fun expiredCancelledUnsolicitedAndRestartedFlowsFailClosed() {
        val guard = XCallbackGuard()
        assertFalse(guard.prepare("", target, 0))
        assertFalse(guard.prepare(target, "com.example.caption:/wrong", 0))
        assertFalse(guard.consume(target, "$target?code=a&state=b", 0))
        assertTrue(guard.prepare(target, target, 0))
        assertFalse(guard.prepare(target, target, 1))
        assertFalse(guard.consume(target, "$target?code=a&state=b", 600001))
        assertTrue(guard.prepare(target, target, 600002))
        guard.clear()
        assertFalse(guard.consume(target, "$target?code=a&state=b", 600003))
        assertFalse(XCallbackGuard().consume(target, "$target?code=a&state=b", 10))
    }
}
