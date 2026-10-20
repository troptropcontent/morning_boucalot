package com.morningboucalot.offload.data

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.emptyFlow

class FakeOffloadedFileDao(var rows: List<OffloadedFile> = emptyList()) : OffloadedFileDao {
    override suspend fun allKeys() = rows.map { it.fileKey }

    override suspend fun insertAll(files: List<OffloadedFile>) {
        rows = rows + files.filter { new -> rows.none { it.fileKey == new.fileKey } }
    }

    override suspend fun update(file: OffloadedFile) {
        rows = rows.map { if (it.fileKey == file.fileKey) file else it }
    }

    override suspend fun pending(limit: Int) =
        rows.filter { it.status == Status.PENDING }.sortedBy { it.fileKey }.take(limit)

    override suspend fun pendingCount() = rows.count { it.status == Status.PENDING }

    override suspend fun resetUploading() {
        rows = rows.map { if (it.status == Status.UPLOADING) it.copy(status = Status.PENDING) else it }
    }

    override suspend fun refreshUri(fileKey: String, uri: String) {
        rows = rows.map { if (it.fileKey == fileKey) it.copy(uri = uri) else it }
    }

    override fun counts(): Flow<List<StatusCount>> = emptyFlow()

    fun row(name: String) = rows.single { it.name == name }
}
