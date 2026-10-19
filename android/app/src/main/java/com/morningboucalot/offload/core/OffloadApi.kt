package com.morningboucalot.offload.core

import okhttp3.HttpUrl
import okhttp3.MediaType
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okio.BufferedSink
import okio.source
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.io.InputStream

/** A non-2xx answer from the checksum pre-check. */
class ApiException(val code: Int) : Exception("server answered $code")

/**
 * Client for the Rails offload endpoints (POST /offload_uploads and
 * POST /offload_uploads/check), authenticated with a shared bearer token.
 */
class OffloadApi(
    private val baseUrl: HttpUrl,
    private val token: String,
    private val client: OkHttpClient = OkHttpClient(),
    allowInsecure: Boolean = false,
) : OffloadServer {
    init {
        require(allowInsecure || baseUrl.isHttps) { "server URL must be https" }
    }

    override fun known(checksums: List<String>): Set<String> {
        val result = mutableSetOf<String>()

        for (chunk in checksums.chunked(MAX_CHECKSUMS_PER_REQUEST)) {
            val body = JSONObject().put("checksums", JSONArray(chunk)).toString().toRequestBody(JSON)
            val request = authorized("offload_uploads/check").post(body).build()

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw ApiException(response.code)
                val known = JSONObject(response.body!!.string()).getJSONArray("known")
                for (i in 0 until known.length()) result += known.getString(i)
            }
        }

        return result
    }

    override fun upload(file: CardFile, open: () -> InputStream): UploadOutcome {
        val body = MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("file", file.name, StreamingBody(mediaTypeFor(file), file.size, open))
            .build()
        val request = authorized("offload_uploads").post(body).build()

        return try {
            client.newCall(request).execute().use { UploadOutcome.fromStatus(it.code) }
        } catch (e: IOException) {
            UploadOutcome.Retry(e.message ?: "network error")
        }
    }

    override fun uploadRaf(file: CardFile, open: () -> InputStream): UploadOutcome = try {
        presign(file)?.let { put(it, file, open) } ?: UploadOutcome.Duplicate
    } catch (e: PresignRejected) {
        e.outcome
    } catch (e: IOException) {
        UploadOutcome.Retry(e.message ?: "network error")
    }

    private class PresignRejected(val outcome: UploadOutcome) : Exception()

    // Null when the server says S3 already has this RAF.
    private fun presign(file: CardFile): String? {
        val body = JSONObject().put("filename", file.name).put("size", file.size).toString().toRequestBody(JSON)
        val request = authorized("raf_uploads/presign").post(body).build()

        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw PresignRejected(UploadOutcome.fromStatus(response.code))
            val json = JSONObject(response.body!!.string())
            return if (json.getBoolean("already_uploaded")) null else json.getString("url")
        }
    }

    // No bearer token here: the URL carries its own signature, and S3 would
    // reject a request with an unexpected Authorization header.
    private fun put(url: String, file: CardFile, open: () -> InputStream): UploadOutcome {
        val request = Request.Builder().url(url).put(StreamingBody(OCTET_STREAM, file.size, open)).build()

        client.newCall(request).execute().use {
            return if (it.isSuccessful) UploadOutcome.Uploaded else UploadOutcome.Retry("S3 answered ${it.code}")
        }
    }

    private fun authorized(path: String): Request.Builder =
        Request.Builder()
            .url(baseUrl.resolve(path) ?: throw IllegalArgumentException("bad path $path"))
            .header("Authorization", "Bearer $token")

    private fun mediaTypeFor(file: CardFile): MediaType =
        if (file.extension == "raf") OCTET_STREAM else JPEG

    // Streams from the content URI instead of buffering: RAFs are tens of MB.
    private class StreamingBody(
        private val type: MediaType,
        private val length: Long,
        private val open: () -> InputStream,
    ) : RequestBody() {
        override fun contentType() = type
        override fun contentLength() = length
        override fun writeTo(sink: BufferedSink) {
            open().source().use { sink.writeAll(it) }
        }
    }

    companion object {
        const val MAX_CHECKSUMS_PER_REQUEST = 1000
        private val JSON = "application/json".toMediaType()
        private val JPEG = "image/jpeg".toMediaType()
        private val OCTET_STREAM = "application/octet-stream".toMediaType()
    }
}
