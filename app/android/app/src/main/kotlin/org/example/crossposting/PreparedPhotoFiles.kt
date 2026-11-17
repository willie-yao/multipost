package org.example.crossposting

import android.content.Context
import java.io.File
import java.io.InputStream
import java.security.MessageDigest

/** Only canonical immutable files in filesDir/instagram-packages may cross out. */
class PreparedPhotoFiles(context: Context) {
    private val root by lazy { File(context.filesDir, "instagram-packages").canonicalFile }
    private val uuid = "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"

    fun file(sourcePath: String, mimeType: String, expectedHash: String): File {
        require(Regex("^[0-9a-f]{64}$").matches(expectedHash))
        val source = File(sourcePath)
        require(source.isAbsolute && sourcePath.split(File.separatorChar).none { it == "." || it == ".." })
        // /data/user/0 and /data/data are Android aliases; compare canonical paths.
        val file = source.canonicalFile
        require(file.path.startsWith(root.path + File.separator))
        val relative = file.relativeTo(root).invariantSeparatorsPath
        require(Regex("^$uuid/(0[1-9]|1[0-9]|20)\\.(png|jpg)$").matches(relative))
        require(mimeType == if (file.extension == "png") "image/png" else "image/jpeg")
        return file
    }

    fun verify(file: File, expectedHash: String) {
        require(file.isFile && file.canRead())
        require(hash(file.inputStream()) == expectedHash)
    }

    fun hash(input: InputStream): String = input.use {
        val digest = MessageDigest.getInstance("SHA-256")
        val buffer = ByteArray(64 * 1024)
        while (true) {
            val count = it.read(buffer)
            if (count < 0) break
            digest.update(buffer, 0, count)
        }
        digest.digest().joinToString("") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }
}
