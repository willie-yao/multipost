package org.example.crossposting

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

internal class XTextChannel(messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "crossposting/x-text")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "measure") {
                result.notImplemented()
            } else {
                val text = call.arguments as? String
                if (text == null) result.error("invalid-text", "Text is required", null)
                else try { result.success(XTextParser.measure(text)) }
                catch (_: Exception) { result.error("text-unavailable", "Text validation unavailable", null) }
            }
        }
    }
    fun dispose() { channel.setMethodCallHandler(null) }
}
