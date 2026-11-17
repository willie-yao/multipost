package org.example.crossposting

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var publishingChannel: PublishingChannel? = null
    private var xTextChannel: XTextChannel? = null
    private var accountsChannel: AccountsChannel? = null
    private var mediaProbe: MediaProbe? = null
    private var mediaExporter: MediaExporter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        publishingChannel = PublishingChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        xTextChannel = XTextChannel(flutterEngine.dartExecutor.binaryMessenger)
        accountsChannel = AccountsChannel(this, flutterEngine)
        mediaProbe = MediaProbe(this, flutterEngine.dartExecutor.binaryMessenger)
        mediaExporter = MediaExporter(this, flutterEngine.dartExecutor.binaryMessenger, InstagramTransfer(this))
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        publishingChannel?.dispose()
        publishingChannel = null
        xTextChannel?.dispose()
        xTextChannel = null
        accountsChannel?.dispose()
        accountsChannel = null
        mediaExporter?.dispose()
        mediaExporter = null
        mediaProbe?.dispose()
        mediaProbe = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
