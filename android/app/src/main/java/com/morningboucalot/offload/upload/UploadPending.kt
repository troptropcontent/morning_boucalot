package com.morningboucalot.offload.upload

import com.morningboucalot.offload.core.ApiException
import com.morningboucalot.offload.core.Checksums
import com.morningboucalot.offload.core.OffloadServer
import com.morningboucalot.offload.core.UploadOutcome
import com.morningboucalot.offload.data.OffloadedFile
import com.morningboucalot.offload.data.OffloadedFileDao
import com.morningboucalot.offload.data.Status
import java.io.IOException
import java.io.InputStream

/**
 * Works through the PENDING queue: hash a batch of JPEGs, ask the server which
 * checksums it already has (those are marked DONE without uploading), upload
 * the rest one at a time. RAFs (~50MB) are neither hashed nor sent through
 * Rails: they go straight to S3 via a presigned URL, and the server dedupes
 * them by filename. Every state change is written to the database as it
 * happens, so a killed run resumes where it stopped.
 *
 * Stops early (leaving the remaining rows PENDING) when going on can't help:
 * bad token, no network, or the card is gone.
 */
class UploadPending(
    private val dao: OffloadedFileDao,
    private val server: OffloadServer,
    private val open: (uri: String) -> InputStream,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    enum class StopReason { AUTH, NETWORK, CARD_UNAVAILABLE }

    data class Summary(
        val uploaded: Int = 0,
        val duplicates: Int = 0,
        val failed: Int = 0,
        val stoppedBecause: StopReason? = null,
    )

    data class Progress(val processed: Int, val total: Int)

    suspend fun run(onProgress: suspend (Progress) -> Unit = {}): Summary {
        dao.resetUploading()
        val total = dao.pendingCount()
        var summary = Summary()
        var processed = 0
        onProgress(Progress(processed, total))

        while (true) {
            val batch = dao.pending(BATCH_SIZE)
            if (batch.isEmpty()) return summary

            val hashed = hashAll(batch) ?: return summary.copy(stoppedBecause = StopReason.CARD_UNAVAILABLE)
            val checksums = hashed.mapNotNull { it.checksum }
            val known = try {
                if (checksums.isEmpty()) emptySet() else server.known(checksums)
            } catch (e: ApiException) {
                return summary.copy(stoppedBecause = if (e.code == 401) StopReason.AUTH else StopReason.NETWORK)
            } catch (e: IOException) {
                return summary.copy(stoppedBecause = StopReason.NETWORK)
            }

            for (row in hashed) {
                if (row.checksum in known) {
                    dao.update(row.copy(status = Status.DONE, lastError = null, updatedAt = clock()))
                    summary = summary.copy(duplicates = summary.duplicates + 1)
                } else {
                    dao.update(row.copy(status = Status.UPLOADING, updatedAt = clock()))
                    val card = row.toCardFile()
                    val outcome = if (card.extension == "raf") {
                        server.uploadRaf(card) { open(row.uri) }
                    } else {
                        server.upload(card) { open(row.uri) }
                    }
                    when (outcome) {
                        UploadOutcome.Uploaded -> {
                            finish(row, Status.DONE)
                            summary = summary.copy(uploaded = summary.uploaded + 1)
                        }
                        UploadOutcome.Duplicate -> {
                            finish(row, Status.DONE)
                            summary = summary.copy(duplicates = summary.duplicates + 1)
                        }
                        is UploadOutcome.PermanentFailure -> {
                            finish(row, Status.FAILED, outcome.reason)
                            summary = summary.copy(failed = summary.failed + 1)
                        }
                        UploadOutcome.AuthFailure -> {
                            finish(row, Status.PENDING, "unauthorized")
                            return summary.copy(stoppedBecause = StopReason.AUTH)
                        }
                        is UploadOutcome.Retry -> {
                            val attempts = row.attempts + 1
                            if (attempts >= MAX_ATTEMPTS) {
                                finish(row.copy(attempts = attempts), Status.FAILED, outcome.reason)
                                summary = summary.copy(failed = summary.failed + 1)
                            } else {
                                finish(row.copy(attempts = attempts), Status.PENDING, outcome.reason)
                                return summary.copy(stoppedBecause = StopReason.NETWORK)
                            }
                        }
                    }
                }
                processed++
                onProgress(Progress(processed, total))
            }
        }
    }

    // Null when the card can't be read (pulled, permission revoked): nothing
    // has been changed yet, so the rows simply stay PENDING for next time.
    private fun hashAll(rows: List<OffloadedFile>): List<OffloadedFile>? = try {
        rows.map { if (it.isRaw()) it else it.copy(checksum = it.checksum ?: Checksums.base64Md5(open(it.uri))) }
    } catch (e: IOException) {
        null
    } catch (e: SecurityException) {
        null
    }

    private fun OffloadedFile.isRaw() = toCardFile().extension == "raf"

    private suspend fun finish(row: OffloadedFile, status: Status, error: String? = null) =
        dao.update(row.copy(status = status, lastError = error, updatedAt = clock()))

    companion object {
        const val BATCH_SIZE = 20

        /** A file that keeps hitting server/network errors is parked as FAILED so it can't block the queue. */
        const val MAX_ATTEMPTS = 5
    }
}
