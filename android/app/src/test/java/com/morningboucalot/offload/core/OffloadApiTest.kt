package com.morningboucalot.offload.core

import okhttp3.mockwebserver.MockResponse
import okhttp3.mockwebserver.MockWebServer
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class OffloadApiTest {
    private lateinit var server: MockWebServer
    private lateinit var api: OffloadApi
    private val jpeg = CardFile("100_FUJI", "DSCF0001.JPG", 5, 0, "content://card/1")

    @Before fun setUp() {
        server = MockWebServer().also { it.start() }
        api = OffloadApi(server.url("/"), "secret", allowInsecure = true)
    }

    @After fun tearDown() {
        runCatching { server.shutdown() }
    }

    @Test fun `refuses a plain http server url by default`() {
        assertThrows(IllegalArgumentException::class.java) { OffloadApi(server.url("/"), "secret") }
    }

    @Test fun `known posts the checksums with the bearer token and returns the server's answer`() {
        server.enqueue(MockResponse().setBody("""{"known":["aaa"]}"""))

        val known = api.known(listOf("aaa", "bbb"))

        val request = server.takeRequest()
        assertEquals("/offload_uploads/check", request.path)
        assertEquals("Bearer secret", request.getHeader("Authorization"))
        assertEquals(listOf("aaa", "bbb"), JSONObject(request.body.readUtf8()).getJSONArray("checksums").let { a -> (0 until a.length()).map { a.getString(it) } })
        assertEquals(setOf("aaa"), known)
    }

    @Test fun `known splits large lists into requests of at most 1000`() {
        server.enqueue(MockResponse().setBody("""{"known":["c0"]}"""))
        server.enqueue(MockResponse().setBody("""{"known":["c1000"]}"""))

        val known = api.known((0..1000).map { "c$it" })

        assertEquals(2, server.requestCount)
        assertEquals(setOf("c0", "c1000"), known)
    }

    @Test fun `known throws ApiException on a non-2xx answer`() {
        server.enqueue(MockResponse().setResponseCode(401))

        val error = assertThrows(ApiException::class.java) { api.known(listOf("aaa")) }

        assertEquals(401, error.code)
    }

    @Test fun `upload sends the file as multipart and maps 201 to Uploaded`() {
        server.enqueue(MockResponse().setResponseCode(201).setBody("""{"status":"created","id":1}"""))

        val outcome = api.upload(jpeg) { "hello".byteInputStream() }

        val request = server.takeRequest()
        assertEquals(UploadOutcome.Uploaded, outcome)
        assertEquals("/offload_uploads", request.path)
        assertEquals("Bearer secret", request.getHeader("Authorization"))
        val body = request.body.readUtf8()
        assertTrue(body.contains("""name="file"; filename="DSCF0001.JPG""""))
        assertTrue(body.contains("Content-Type: image/jpeg"))
        assertTrue(body.contains("hello"))
    }

    @Test fun `upload sends RAF files as octet-stream`() {
        server.enqueue(MockResponse().setResponseCode(201))

        api.upload(jpeg.copy(name = "DSCF0001.RAF")) { "hello".byteInputStream() }

        assertTrue(server.takeRequest().body.readUtf8().contains("Content-Type: application/octet-stream"))
    }

    @Test fun `upload maps 200 to Duplicate and 422 to a permanent failure`() {
        server.enqueue(MockResponse().setResponseCode(200).setBody("""{"status":"duplicate"}"""))
        server.enqueue(MockResponse().setResponseCode(422))

        assertEquals(UploadOutcome.Duplicate, api.upload(jpeg) { "hello".byteInputStream() })
        assertTrue(api.upload(jpeg) { "hello".byteInputStream() } is UploadOutcome.PermanentFailure)
    }

    @Test fun `upload retries when the server cannot be reached`() {
        server.shutdown()

        assertTrue(api.upload(jpeg) { "hello".byteInputStream() } is UploadOutcome.Retry)
    }
}
