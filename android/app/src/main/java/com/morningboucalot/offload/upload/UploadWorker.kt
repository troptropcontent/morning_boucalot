package com.morningboucalot.offload.upload

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.net.Uri
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import com.morningboucalot.offload.data.OffloadDatabase
import com.morningboucalot.offload.settings.Settings
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.FileNotFoundException
import java.io.InputStream

/** Thin Android shell around [UploadPending]: settings in, foreground notification out. */
class UploadWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val api = Settings(applicationContext).api() ?: return Result.failure()
        val dao = OffloadDatabase.get(applicationContext).dao()

        setForeground(foregroundInfo("Preparing…"))

        val summary = withContext(Dispatchers.IO) {
            UploadPending(dao, api, ::openUri).run { progress ->
                setForeground(foregroundInfo("Uploading ${progress.processed} of ${progress.total}"))
            }
        }

        val stopMsg = when (summary.stoppedBecause) {
            UploadPending.StopReason.NETWORK -> "Network error — will retry"
            UploadPending.StopReason.AUTH -> "Auth failed — check token"
            UploadPending.StopReason.CARD_UNAVAILABLE -> "Card unavailable — reconnect and retry"
            null -> null
        }
        Settings(applicationContext).lastUploadError = stopMsg

        return when (summary.stoppedBecause) {
            UploadPending.StopReason.NETWORK -> Result.retry()
            UploadPending.StopReason.AUTH -> Result.failure()
            UploadPending.StopReason.CARD_UNAVAILABLE, null -> Result.success()
        }
    }

    private fun openUri(uri: String): InputStream =
        applicationContext.contentResolver.openInputStream(Uri.parse(uri))
            ?: throw FileNotFoundException(uri)

    private fun foregroundInfo(text: String): ForegroundInfo {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Photo offload", NotificationManager.IMPORTANCE_LOW),
        )
        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_upload)
            .setContentTitle("Boucalot Offload")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        return ForegroundInfo(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    }

    private companion object {
        const val CHANNEL_ID = "offload"
        const val NOTIFICATION_ID = 1
    }
}
