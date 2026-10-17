package com.morningboucalot.offload.core

/** Decides which scanned card files still need offloading. Pure, no Android deps. */
object ScanPlanner {
    val SUPPORTED_EXTENSIONS = setOf("jpg", "jpeg", "raf")

    /** Files modified more recently than this might still be mid-write. */
    const val STABLE_AFTER_MS = 10_000L

    data class Plan(val toQueue: List<CardFile>, val alreadyKnown: Int, val unstable: Int)

    fun plan(files: List<CardFile>, knownKeys: Set<String>, nowMs: Long): Plan {
        val toQueue = mutableListOf<CardFile>()
        var alreadyKnown = 0
        var unstable = 0

        for (file in files) {
            if (file.name.startsWith(".") || file.extension !in SUPPORTED_EXTENSIONS) continue

            when {
                file.key in knownKeys -> alreadyKnown++
                isPossiblyBeingWritten(file, nowMs) -> unstable++
                else -> toQueue += file
            }
        }

        return Plan(toQueue, alreadyKnown, unstable)
    }

    // A negative age (camera clock ahead of the phone, or FAT's timezone-less
    // timestamps) can't be judged, so it counts as stable rather than
    // blocking the file forever. A size-unchanged-across-two-scans check is
    // the sturdier follow-up.
    private fun isPossiblyBeingWritten(file: CardFile, nowMs: Long): Boolean =
        nowMs - file.lastModified in 0 until STABLE_AFTER_MS
}
