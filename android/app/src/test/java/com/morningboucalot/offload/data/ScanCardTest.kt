package com.morningboucalot.offload.data

import com.morningboucalot.offload.core.CardFile
import com.morningboucalot.offload.scan.ScanCard
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ScanCardTest {
    private class FakeDao(var rows: List<OffloadedFile> = emptyList()) : OffloadedFileDao {
        override suspend fun allKeys() = rows.map { it.fileKey }
        override suspend fun insertAll(files: List<OffloadedFile>) {
            rows = rows + files.filter { new -> rows.none { it.fileKey == new.fileKey } }
        }
        override fun counts(): Flow<List<StatusCount>> = emptyFlow()
    }

    private fun card(name: String) = CardFile("100_FUJI", name, 5_000, 0, "content://card/$name")

    @Test fun `records new files as pending`() = runBlocking {
        val dao = FakeDao()

        val plan = ScanCard({ listOf(card("DSCF0001.JPG")) }, dao, clock = { 1_000_000L }).run()

        assertEquals(1, plan.toQueue.size)
        assertEquals(listOf(Status.PENDING), dao.rows.map { it.status })
        assertEquals(1_000_000L, dao.rows.single().updatedAt)
    }

    @Test fun `a second scan of the same card queues nothing`() = runBlocking {
        val dao = FakeDao()
        val scan = ScanCard({ listOf(card("DSCF0001.JPG")) }, dao)
        scan.run()

        val plan = scan.run()

        assertEquals(0, plan.toQueue.size)
        assertEquals(1, plan.alreadyKnown)
        assertEquals(1, dao.rows.size)
    }
}
