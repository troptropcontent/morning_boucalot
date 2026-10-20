package com.morningboucalot.offload.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

data class StatusCount(val status: Status, val count: Int)

@Dao
interface OffloadedFileDao {
    /** Every key we've ever recorded, whatever its status: none of them get re-queued by a scan. */
    @Query("SELECT fileKey FROM offloaded_files")
    suspend fun allKeys(): List<String>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(files: List<OffloadedFile>)

    @Update
    suspend fun update(file: OffloadedFile)

    @Query("SELECT * FROM offloaded_files WHERE status = 'PENDING' ORDER BY fileKey LIMIT :limit")
    suspend fun pending(limit: Int): List<OffloadedFile>

    @Query("SELECT COUNT(*) FROM offloaded_files WHERE status = 'PENDING'")
    suspend fun pendingCount(): Int

    /** A run that died mid-file (app killed, card pulled) leaves rows UPLOADING; put them back in line. */
    @Query("UPDATE offloaded_files SET status = 'PENDING' WHERE status = 'UPLOADING'")
    suspend fun resetUploading()

    /** Keeps URI fresh after MTP session resets between uses. */
    @Query("UPDATE offloaded_files SET uri = :uri WHERE fileKey = :fileKey")
    suspend fun refreshUri(fileKey: String, uri: String)

    @Query("SELECT status, COUNT(*) AS count FROM offloaded_files GROUP BY status")
    fun counts(): Flow<List<StatusCount>>
}
