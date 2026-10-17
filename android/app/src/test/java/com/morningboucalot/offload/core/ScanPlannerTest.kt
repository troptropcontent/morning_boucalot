package com.morningboucalot.offload.core

import org.junit.Assert.assertEquals
import org.junit.Test

class ScanPlannerTest {
    private val now = 1_000_000L

    private fun file(name: String, folder: String = "100_FUJI", size: Long = 5_000, modified: Long = 0) =
        CardFile(folder, name, size, modified, "content://card/$folder/$name")

    @Test fun `queues unseen supported files`() {
        val plan = ScanPlanner.plan(listOf(file("DSCF0001.JPG"), file("DSCF0001.RAF")), emptySet(), now)

        assertEquals(listOf("DSCF0001.JPG", "DSCF0001.RAF"), plan.toQueue.map { it.name })
    }

    @Test fun `skips files whose key is already known`() {
        val seen = file("DSCF0001.JPG")

        val plan = ScanPlanner.plan(listOf(seen, file("DSCF0002.JPG")), setOf(seen.key), now)

        assertEquals(listOf("DSCF0002.JPG"), plan.toQueue.map { it.name })
        assertEquals(1, plan.alreadyKnown)
    }

    @Test fun `same name in another folder or with another size is a new file`() {
        val seen = file("DSCF0001.JPG")
        val otherFolder = file("DSCF0001.JPG", folder = "101_FUJI")
        val otherSize = file("DSCF0001.JPG", size = 6_000)

        val plan = ScanPlanner.plan(listOf(otherFolder, otherSize), setOf(seen.key), now)

        assertEquals(2, plan.toQueue.size)
    }

    @Test fun `ignores unsupported and hidden files`() {
        val files = listOf(file("notes.txt"), file("._DSCF0001.JPG"), file("DSCF0001.MOV"), file("dscf0002.jpeg"))

        val plan = ScanPlanner.plan(files, emptySet(), now)

        assertEquals(listOf("dscf0002.jpeg"), plan.toQueue.map { it.name })
    }

    @Test fun `holds back files modified moments ago`() {
        val fresh = file("DSCF0003.JPG", modified = now - 2_000)
        val settled = file("DSCF0004.JPG", modified = now - ScanPlanner.STABLE_AFTER_MS)

        val plan = ScanPlanner.plan(listOf(fresh, settled), emptySet(), now)

        assertEquals(listOf("DSCF0004.JPG"), plan.toQueue.map { it.name })
        assertEquals(1, plan.unstable)
    }

    @Test fun `a modified time in the future does not block the file`() {
        val plan = ScanPlanner.plan(listOf(file("DSCF0005.JPG", modified = now + 3_600_000)), emptySet(), now)

        assertEquals(1, plan.toQueue.size)
    }
}
