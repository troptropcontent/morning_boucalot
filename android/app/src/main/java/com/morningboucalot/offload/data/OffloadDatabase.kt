package com.morningboucalot.offload.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase

@Database(entities = [OffloadedFile::class], version = 1, exportSchema = true)
abstract class OffloadDatabase : RoomDatabase() {
    abstract fun dao(): OffloadedFileDao

    companion object {
        @Volatile private var instance: OffloadDatabase? = null

        fun get(context: Context): OffloadDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(context.applicationContext, OffloadDatabase::class.java, "offload.db")
                    .build()
                    .also { instance = it }
            }
    }
}
