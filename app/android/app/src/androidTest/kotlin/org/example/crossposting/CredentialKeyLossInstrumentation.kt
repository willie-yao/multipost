package org.example.crossposting

import android.app.Activity
import android.app.Instrumentation
import android.os.Bundle
import com.it_nomads.fluttersecurestorage.FlutterSecureStorage
import com.it_nomads.fluttersecurestorage.FlutterSecureStorageConfig
import com.it_nomads.fluttersecurestorage.SecurePreferencesCallback
import java.io.File
import java.security.KeyStore
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import org.json.JSONObject

/** TEST APK ONLY: one guarded lost-X-wrapping-key simulation, no production hook. */
class CredentialKeyLossInstrumentation : Instrumentation() {
    private var fixtureId = ""
    private var phase = ""
    override fun onCreate(arguments: Bundle?) {
        super.onCreate(arguments)
        fixtureId = arguments?.getString("fixtureId") ?: ""
        phase = arguments?.getString("phase") ?: ""
        start()
    }
    override fun onStart() {
        val result = Bundle()
        try {
            check(fixtureId.matches(Regex("[a-f0-9-]{36}")))
            val root = File(targetContext.filesDir, "p2-repair-native-fixture")
            if (phase == "prepare") {
                check(!root.exists())
                val keys = KeyStore.getInstance("AndroidKeyStore")
                keys.load(null)
                for (namespace in listOf("caption_x_credentials", "caption_bluesky_credentials")) {
                    check(!keys.containsAlias("org.example.crossposting.FlutterSecureStoragePluginKeyOAEP.$namespace"))
                    for (name in listOf(namespace, "FlutterSecureKeyStorage:$namespace",
                        "FlutterSecureStorageConfiguration:$namespace")) {
                        check(targetContext.getSharedPreferences(name, 0).all.isEmpty())
                    }
                }
                check(root.mkdir())
                java.io.FileOutputStream(File(root, "marker")).use {
                    it.write(fixtureId.toByteArray(Charsets.UTF_8)); it.fd.sync()
                }
                result.putString("p2_result", "P2 empty provider namespaces prepared")
                finish(Activity.RESULT_OK, result)
                return
            }
            check(phase == "loseXKey")
            check(File(root, "marker").readText() == fixtureId)
            check(File(root, "fixture.db").isFile)
            // Verify exact plaintext synthetic provenance through the pinned package,
            // without printing either plaintext or encrypted material.
            val session = JSONObject(readFixture("caption_x_credentials", "session.x"))
            check(session.length() == 7)
            check(session.getInt("version") == 1)
            check(session.getString("expiresAt") == "2027-01-01T00:00:00.000Z")
            check(session.getJSONObject("identity").length() == 3)
            check(session.getJSONObject("identity").getString("destination") == "x")
            check(session.getJSONObject("identity").getString("handle") == "@p2fixture")
            check(session.getString("clientId") == "p2-repair-synthetic")
            check(session.getString("redirectUri") == "com.example.caption:/x")
            check(session.getString("accessToken") == "p2-repair-old-access-synthetic")
            check(session.getString("refreshToken") == "p2-repair-old-refresh-synthetic")
            check(session.getJSONObject("identity").getString("subject") == "112233")
            check(readFixture("caption_bluesky_credentials", "session.bluesky") == "p2-repair-bluesky-synthetic-$fixtureId")
            val keys = KeyStore.getInstance("AndroidKeyStore")
            keys.load(null)
            val xAlias = "org.example.crossposting.FlutterSecureStoragePluginKeyOAEP.caption_x_credentials"
            val bAlias = "org.example.crossposting.FlutterSecureStoragePluginKeyOAEP.caption_bluesky_credentials"
            check(keys.containsAlias(xAlias) && keys.containsAlias(bAlias))
            // Delete exactly the known fixture X alias; never enumerate-delete keys.
            keys.deleteEntry(xAlias)
            check(!keys.containsAlias(xAlias) && keys.containsAlias(bAlias))
            result.putString("p2_result", "P2 guarded X key loss verified")
            finish(Activity.RESULT_OK, result)
        } catch (_: Exception) {
            result.putString("p2_result", "Guarded key loss simulation failed; fixtures preserved")
            finish(Activity.RESULT_CANCELED, result)
        }
    }
    private fun readFixture(namespace: String, key: String): String {
        val latch = CountDownLatch(1)
        var value: String? = null
        var failed = false
        val storage = FlutterSecureStorage(targetContext)
        val config = FlutterSecureStorageConfig(mapOf(
            "storageNamespace" to namespace, "resetOnError" to "false"))
        storage.initialize(config, object : SecurePreferencesCallback<Void> {
            override fun onSuccess(unused: Void?) {
                storage.read(storage.addPrefixToKey(key), object : SecurePreferencesCallback<String> {
                    override fun onSuccess(stored: String?) { value = stored; latch.countDown() }
                    override fun onError(error: Exception) { failed = true; latch.countDown() }
                })
            }
            override fun onError(error: Exception) { failed = true; latch.countDown() }
        })
        check(latch.await(20, TimeUnit.SECONDS) && !failed && value != null)
        return value!!
    }
}
