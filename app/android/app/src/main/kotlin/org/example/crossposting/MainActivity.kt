package org.example.crossposting

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var mediaProbe: MediaProbe? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        mediaProbe = MediaProbe(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        mediaProbe?.dispose()
        mediaProbe = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
