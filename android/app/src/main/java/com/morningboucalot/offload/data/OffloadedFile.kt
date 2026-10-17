package com.morningboucalot.offload.data

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.morningboucalot.offload.core.CardFile

enum class Status { PENDING, UPLOADING, DONE, FAILED }

/** One card file the app knows about, and how far along its offload is. */
@Entity(tableName = "offloaded_files")
data class OffloadedFile(
    @PrimaryKey val fileKey: String,
    val uri: String,
    val folder: String,
    val name: String,
    val size: Long,
    val checksum: String? = null,
    val status: Status = Status.PENDING,
    val attempts: Int = 0,
    val lastError: String? = null,
    val updatedAt: Long,
) {
    fun toCardFile() = CardFile(folder, name, size, lastModified = 0, uri = uri)

    companion object {
        fun pending(file: CardFile, nowMs: Long) = OffloadedFile(
            fileKey = file.key,
            uri = file.uri,
            folder = file.folder,
            name = file.name,
            size = file.size,
            updatedAt = nowMs,
        )
    }
}
