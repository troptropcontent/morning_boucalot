package com.morningboucalot.offload.core

import org.junit.Assert.assertEquals
import org.junit.Test

class ChecksumsTest {
    @Test fun `matches the base64 md5 Active Storage would store`() {
        assertEquals("XUFAKrxLKna5cZ2REBfFkg==", Checksums.base64Md5("hello".byteInputStream()))
    }

    @Test fun `handles input larger than its read buffer`() {
        val data = ByteArray(200_000) { (it % 251).toByte() }
        val expected = java.util.Base64.getEncoder().encodeToString(
            java.security.MessageDigest.getInstance("MD5").digest(data),
        )

        assertEquals(expected, Checksums.base64Md5(data.inputStream()))
    }
}
