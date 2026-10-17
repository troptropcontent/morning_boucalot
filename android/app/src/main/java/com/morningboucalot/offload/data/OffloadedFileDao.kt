package com.morningboucalot.offload.data

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

data class StatusCount(val status: Status, val count: Int)

@Dao
interface OffloadedFileDao {
    /** Every key we've ever recorded, whatever its status: none of them get re-queued by a scan. */
    @Query("SELECT fileKey FROM offloaded_files")
    suspend fun allKeys(): List<String>

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertAll(files: List<OffloadedFile>)

    @Query("SELECT status, COUNT(*) AS count FROM offloaded_files GROUP BY status")
    fun counts(): Flow<List<StatusCount>>
}
