package com.morningboucalot.offload.data

import com.morningboucalot.offload.core.CardFile
import com.morningboucalot.offload.scan.ScanCard
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test

class ScanCardTest {
    private fun card(name: String) = CardFile("100_FUJI", name, 5_000, 0, "content://card/$name")

    @Test fun `records new files as pending`() = runBlocking {
        val dao = FakeOffloadedFileDao()

        val plan = ScanCard({ listOf(card("DSCF0001.JPG")) }, dao, clock = { 1_000_000L }).run()

        assertEquals(1, plan.toQueue.size)
        assertEquals(listOf(Status.PENDING), dao.rows.map { it.status })
        assertEquals(1_000_000L, dao.rows.single().updatedAt)
    }

    @Test fun `a second scan of the same card queues nothing`() = runBlocking {
        val dao = FakeOffloadedFileDao()
        val scan = ScanCard({ listOf(card("DSCF0001.JPG")) }, dao)
        scan.run()

        val plan = scan.run()

        assertEquals(0, plan.toQueue.size)
        assertEquals(1, plan.alreadyKnown)
        assertEquals(1, dao.rows.size)
    }

    @Test fun `a later scan refreshes the URI of an already-known file`() = runBlocking {
        val dao = FakeOffloadedFileDao()
        ScanCard({ listOf(card("DSCF0001.JPG")) }, dao).run()
        dao.rows = dao.rows.map { it.copy(uri = "content://card/stale") }

        ScanCard({ listOf(card("DSCF0001.JPG")) }, dao).run()

        assertEquals("content://card/DSCF0001.JPG", dao.rows.single().uri)
    }
}
