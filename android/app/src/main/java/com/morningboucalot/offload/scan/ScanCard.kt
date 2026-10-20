package com.morningboucalot.offload.scan

import com.morningboucalot.offload.core.CardFile
import com.morningboucalot.offload.core.ScanPlanner
import com.morningboucalot.offload.data.OffloadedFile
import com.morningboucalot.offload.data.OffloadedFileDao

/**
 * One scan pass: list the card, drop what we already know, record the rest as
 * PENDING for the upload worker. [listFiles] is injected so this is testable
 * without a real card.
 */
class ScanCard(
    private val listFiles: () -> List<CardFile>,
    private val dao: OffloadedFileDao,
    private val clock: () -> Long = System::currentTimeMillis,
) {
    suspend fun run(): ScanPlanner.Plan {
        val now = clock()
        val files = listFiles()
        val plan = ScanPlanner.plan(files, dao.allKeys().toSet(), now)
        dao.insertAll(plan.toQueue.map { OffloadedFile.pending(it, now) })
        // Refresh URIs for all files already in the DB — MTP reassigns URIs each session.
        for (file in files) dao.refreshUri(file.key, file.uri)
        return plan
    }
}
