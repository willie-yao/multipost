package org.example.crossposting

import com.twitter.twittertext.TwitterTextParser

/** Exact official Maven parser; no app-owned Unicode or URL algorithm. */
internal object XTextParser {
    fun measure(text: String): Map<String, Any> {
        val result = TwitterTextParser.parseTweet(text)
        return mapOf("units" to result.weightedLength, "valid" to result.isValid)
    }
}
