package com.morningboucalot.offload.upload

import com.morningboucalot.offload.core.ApiException
import com.morningboucalot.offload.core.CardFile
import com.morningboucalot.offload.core.Checksums
import com.morningboucalot.offload.core.OffloadServer
import com.morningboucalot.offload.core.UploadOutcome
import com.morningboucalot.offload.data.FakeOffloadedFileDao
import com.morningboucalot.offload.data.OffloadedFile
import com.morningboucalot.offload.data.Status
import com.morningboucalot.offload.upload.UploadPending.StopReason
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.io.FileNotFoundException
import java.io.IOException
import java.io.InputStream

class UploadPendingTest {
    private class FakeServer : OffloadServer {
        var known: Set<String> = emptySet()
        var knownError: Exception? = null
        var outcomeFor: (String) -> UploadOutcome = { UploadOutcome.Uploaded }
        val uploaded = mutableListOf<String>()
        val knownCalls = mutableListOf<List<String>>()

        override fun known(checksums: List<String>): Set<String> {
            knownCalls += checksums
            knownError?.let { throw it }
            return checksums.filter { it in known }.toSet()
        }

        override fun upload(file: CardFile, open: () -> InputStream): UploadOutcome {
            uploaded += file.name
            open().close()
            return outcomeFor(file.name)
        }
    }

    private val server = FakeServer()
    private val dao = FakeOffloadedFileDao()

    // The "file" content is just its uri, so checksums are predictable.
    private var open: (String) -> InputStream = { it.toByteArray().inputStream() }

    private fun checksumOf(name: String) = Checksums.base64Md5(uri(name).toByteArray().inputStream())
    private fun uri(name: String) = "content://card/$name"

    private fun pending(vararg names: String, attempts: Int = 0) {
        dao.rows = dao.rows + names.map { name ->
            OffloadedFile(
                fileKey = "100_FUJI/$name/5", uri = uri(name), folder = "100_FUJI", name = name,
                size = 5, attempts = attempts, updatedAt = 0,
            )
        }
    }

    private fun run(onProgress: suspend (UploadPending.Progress) -> Unit = {}) =
        runBlocking { UploadPending(dao, server, { open(it) }, clock = { 99L }).run(onProgress) }

    @Test fun `uploads pending files and marks them done with their checksum`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")

        val summary = run()

        assertEquals(UploadPending.Summary(uploaded = 2), summary)
        assertEquals(listOf("DSCF0001.JPG", "DSCF0002.JPG"), server.uploaded)
        assertEquals(Status.DONE, dao.row("DSCF0001.JPG").status)
        assertEquals(checksumOf("DSCF0001.JPG"), dao.row("DSCF0001.JPG").checksum)
        assertEquals(99L, dao.row("DSCF0001.JPG").updatedAt)
    }

    @Test fun `does not upload files whose checksum the server already has`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")
        server.known = setOf(checksumOf("DSCF0001.JPG"))

        val summary = run()

        assertEquals(UploadPending.Summary(uploaded = 1, duplicates = 1), summary)
        assertEquals(listOf("DSCF0002.JPG"), server.uploaded)
        assertEquals(Status.DONE, dao.row("DSCF0001.JPG").status)
    }

    @Test fun `asks the server about a whole batch in one call`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG", "DSCF0003.JPG")

        run()

        assertEquals(1, server.knownCalls.size)
        assertEquals(3, server.knownCalls.single().size)
    }

    @Test fun `works through more files than one batch`() {
        pending(*(1..UploadPending.BATCH_SIZE + 5).map { "DSCF%04d.JPG".format(it) }.toTypedArray())

        val summary = run()

        assertEquals(UploadPending.BATCH_SIZE + 5, summary.uploaded)
        assertEquals(2, server.knownCalls.size)
    }

    @Test fun `a server duplicate answer counts as done`() {
        pending("DSCF0001.JPG")
        server.outcomeFor = { UploadOutcome.Duplicate }

        val summary = run()

        assertEquals(UploadPending.Summary(duplicates = 1), summary)
        assertEquals(Status.DONE, dao.row("DSCF0001.JPG").status)
    }

    @Test fun `a permanent failure is parked as failed and the rest carry on`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")
        server.outcomeFor = { if (it == "DSCF0001.JPG") UploadOutcome.PermanentFailure("rejected") else UploadOutcome.Uploaded }

        val summary = run()

        assertEquals(UploadPending.Summary(uploaded = 1, failed = 1), summary)
        assertEquals(Status.FAILED, dao.row("DSCF0001.JPG").status)
        assertEquals("rejected", dao.row("DSCF0001.JPG").lastError)
        assertEquals(Status.DONE, dao.row("DSCF0002.JPG").status)
    }

    @Test fun `a bad token stops the run and leaves the file pending`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")
        server.outcomeFor = { UploadOutcome.AuthFailure }

        val summary = run()

        assertEquals(StopReason.AUTH, summary.stoppedBecause)
        assertEquals(listOf("DSCF0001.JPG"), server.uploaded)
        assertEquals(Status.PENDING, dao.row("DSCF0001.JPG").status)
        assertEquals(Status.PENDING, dao.row("DSCF0002.JPG").status)
    }

    @Test fun `a retryable error stops the run, counts an attempt and keeps the file pending`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")
        server.outcomeFor = { UploadOutcome.Retry("server answered 503") }

        val summary = run()

        assertEquals(StopReason.NETWORK, summary.stoppedBecause)
        assertEquals(listOf("DSCF0001.JPG"), server.uploaded)
        assertEquals(Status.PENDING, dao.row("DSCF0001.JPG").status)
        assertEquals(1, dao.row("DSCF0001.JPG").attempts)
        assertEquals("server answered 503", dao.row("DSCF0001.JPG").lastError)
    }

    @Test fun `a file that keeps failing is parked after the maximum attempts so it cannot block the queue`() {
        pending("DSCF0001.JPG", attempts = UploadPending.MAX_ATTEMPTS - 1)
        pending("DSCF0002.JPG")
        server.outcomeFor = { if (it == "DSCF0001.JPG") UploadOutcome.Retry("boom") else UploadOutcome.Uploaded }

        val summary = run()

        assertEquals(UploadPending.Summary(uploaded = 1, failed = 1), summary)
        assertEquals(Status.FAILED, dao.row("DSCF0001.JPG").status)
        assertEquals(Status.DONE, dao.row("DSCF0002.JPG").status)
    }

    @Test fun `an unauthorized pre-check stops before uploading anything`() {
        pending("DSCF0001.JPG")
        server.knownError = ApiException(401)

        val summary = run()

        assertEquals(StopReason.AUTH, summary.stoppedBecause)
        assertEquals(emptyList<String>(), server.uploaded)
        assertEquals(Status.PENDING, dao.row("DSCF0001.JPG").status)
    }

    @Test fun `other pre-check errors and network errors stop the run as a network problem`() {
        pending("DSCF0001.JPG")
        server.knownError = ApiException(503)
        assertEquals(StopReason.NETWORK, run().stoppedBecause)

        server.knownError = IOException("no route")
        assertEquals(StopReason.NETWORK, run().stoppedBecause)
        assertEquals(emptyList<String>(), server.uploaded)
    }

    @Test fun `an unreadable card stops the run without touching any rows`() {
        pending("DSCF0001.JPG")
        open = { throw FileNotFoundException(it) }

        val summary = run()

        assertEquals(StopReason.CARD_UNAVAILABLE, summary.stoppedBecause)
        assertEquals(Status.PENDING, dao.row("DSCF0001.JPG").status)
        assertEquals(0, dao.row("DSCF0001.JPG").attempts)
    }

    @Test fun `revoked folder permission is treated like a missing card`() {
        pending("DSCF0001.JPG")
        open = { throw SecurityException("permission revoked") }

        assertEquals(StopReason.CARD_UNAVAILABLE, run().stoppedBecause)
    }

    @Test fun `files left uploading by a killed run are picked up again`() {
        pending("DSCF0001.JPG")
        dao.rows = dao.rows.map { it.copy(status = Status.UPLOADING) }

        val summary = run()

        assertEquals(1, summary.uploaded)
        assertEquals(Status.DONE, dao.row("DSCF0001.JPG").status)
    }

    @Test fun `reuses a stored checksum instead of reading the file again`() {
        pending("DSCF0001.JPG")
        dao.rows = dao.rows.map { it.copy(checksum = "stored") }
        server.known = setOf("stored")
        open = { throw AssertionError("should not be read") }

        val summary = run()

        assertEquals(1, summary.duplicates)
    }

    @Test fun `reports progress as files are processed`() {
        pending("DSCF0001.JPG", "DSCF0002.JPG")
        val seen = mutableListOf<UploadPending.Progress>()

        run { seen += it }

        assertEquals(
            listOf(UploadPending.Progress(0, 2), UploadPending.Progress(1, 2), UploadPending.Progress(2, 2)),
            seen,
        )
    }

    @Test fun `an empty queue finishes immediately`() {
        val summary = run()

        assertEquals(UploadPending.Summary(), summary)
        assertNull(summary.stoppedBecause)
    }
}
