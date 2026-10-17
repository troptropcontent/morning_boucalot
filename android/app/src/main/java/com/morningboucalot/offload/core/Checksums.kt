package com.morningboucalot.offload.core

import java.io.InputStream
import java.security.MessageDigest
import java.util.Base64

object Checksums {
    /**
     * Base64-encoded MD5, the format Active Storage stores as a blob's
     * checksum, so it can be compared directly with the server's.
     */
    fun base64Md5(input: InputStream): String {
        val digest = MessageDigest.getInstance("MD5")
        val buffer = ByteArray(64 * 1024)
        input.use { stream ->
            while (true) {
                val read = stream.read(buffer)
                if (read < 0) break
                digest.update(buffer, 0, read)
            }
        }
        return Base64.getEncoder().encodeToString(digest.digest())
    }
}
