package com.morningboucalot.offload.ui

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.work.WorkInfo
import androidx.work.WorkManager
import com.morningboucalot.offload.data.OffloadDatabase
import com.morningboucalot.offload.data.Status
import com.morningboucalot.offload.scan.CardScanner
import com.morningboucalot.offload.scan.ScanCard
import com.morningboucalot.offload.settings.Settings
import com.morningboucalot.offload.upload.UploadScheduler
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { OffloadScreen() } }
    }

    @Composable
    private fun OffloadScreen() {
        val settings = remember { Settings(this) }
        val dao = remember { OffloadDatabase.get(this).dao() }
        val scope = rememberCoroutineScope()

        // Session-only: MTP URI permissions don't survive camera reconnections.
        var treeUri by remember { mutableStateOf<String?>(null) }
        var serverUrl by remember { mutableStateOf(settings.serverUrl) }
        var token by remember { mutableStateOf(settings.token) }
        var wifiOnly by remember { mutableStateOf(settings.wifiOnly) }
        var message by remember { mutableStateOf(settings.lastUploadError ?: "") }
        var isScanning by remember { mutableStateOf(false) }
        var scanJob by remember { mutableStateOf<Job?>(null) }
        var showSettings by remember { mutableStateOf(settings.serverUrl.isBlank()) }

        val counts by dao.counts().collectAsState(initial = emptyList())
        val workInfos by WorkManager.getInstance(this)
            .getWorkInfosForUniqueWorkFlow(UploadScheduler.UNIQUE_NAME)
            .collectAsState(initial = emptyList())

        val pending = counts.firstOrNull { it.status == Status.PENDING }?.count ?: 0
        val done = counts.firstOrNull { it.status == Status.DONE }?.count ?: 0
        val failed = counts.firstOrNull { it.status == Status.FAILED }?.count ?: 0
        val uploading = counts.firstOrNull { it.status == Status.UPLOADING }?.count ?: 0
        val total = pending + done + failed + uploading

        val isWorkerRunning = workInfos.any { it.state == WorkInfo.State.RUNNING }
        val isWorkerQueued = workInfos.any {
            it.state == WorkInfo.State.ENQUEUED || it.state == WorkInfo.State.BLOCKED
        }
        val isBusy = isScanning || isWorkerRunning
        val settingsReady = settings.api() != null

        val notificationPermission =
            rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

        val folderPicker =
            rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
                if (uri != null) {
                    contentResolver.takePersistableUriPermission(
                        uri, Intent.FLAG_GRANT_READ_URI_PERMISSION
                    )
                    treeUri = uri.toString()
                    message = ""
                }
            }

        fun startUpload() {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) {
                notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            UploadScheduler.enqueue(this, wifiOnly)
        }

        fun saveSettings(): Boolean {
            val url = serverUrl.trim().toHttpUrlOrNull()
            if (url == null || !url.isHttps) { message = "Server URL must start with https://"; return false }
            if (token.isBlank()) { message = "Enter the upload token"; return false }
            settings.serverUrl = url.toString(); serverUrl = url.toString()
            settings.token = token.trim()
            settings.wifiOnly = wifiOnly
            message = "Settings saved"
            return true
        }

        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            Text("Boucalot Offload", style = MaterialTheme.typography.headlineMedium)

            // ── Step 1: Camera ────────────────────────────────────────────────
            CameraCard(treeUri = treeUri, onPick = { folderPicker.launch(null) })

            // ── Step 2: Status (only once we have history) ────────────────────
            if (total > 0) {
                StatusCard(
                    isScanning = isScanning,
                    isWorkerRunning = isWorkerRunning,
                    isWorkerQueued = isWorkerQueued,
                    wifiOnly = wifiOnly,
                    total = total, pending = pending, uploading = uploading,
                    done = done, failed = failed,
                )
            }

            // ── Step 3: Actions ───────────────────────────────────────────────
            when {
                !settingsReady -> Card(
                    modifier = Modifier.fillMaxWidth(),
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer),
                ) {
                    Text(
                        "Server URL and token required — configure in Settings below",
                        modifier = Modifier.padding(16.dp),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onErrorContainer,
                    )
                }
                treeUri == null -> {} // CameraCard already shows the pick button
                else -> {
                    if (isBusy) {
                        OutlinedButton(
                            onClick = {
                                scanJob?.cancel()
                                scanJob = null
                                WorkManager.getInstance(this@MainActivity).cancelUniqueWork(UploadScheduler.UNIQUE_NAME)
                                isScanning = false
                                message = "Stopped"
                            },
                            modifier = Modifier.fillMaxWidth().height(56.dp),
                        ) {
                            Text("Stop upload")
                        }
                    } else {
                        Button(
                            onClick = {
                                isScanning = true
                                message = ""
                                scanJob = scope.launch {
                                    try {
                                        val uri = Uri.parse(treeUri)
                                        val plan = withContext(Dispatchers.IO) {
                                            ScanCard({ CardScanner(this@MainActivity).list(uri) }, dao).run()
                                        }
                                        // After scan, URIs are fresh — start upload for new or pending files.
                                        if (plan.toQueue.isNotEmpty() || pending > 0) {
                                            startUpload()
                                        } else {
                                            message = "Nothing to upload — all ${plan.alreadyKnown} files already on server"
                                        }
                                    } catch (e: CancellationException) {
                                        throw e
                                    } catch (e: Exception) {
                                        message = "Scan failed: ${e.message}"
                                    } finally {
                                        isScanning = false
                                        scanJob = null
                                    }
                                }
                            },
                            modifier = Modifier.fillMaxWidth().height(56.dp),
                        ) {
                            Text(if (pending > 0) "Scan & resume upload" else "Scan & upload")
                        }
                    }
                }
            }

            if (message.isNotEmpty()) {
                Text(
                    message,
                    color = if (message.startsWith("Settings saved") || message.startsWith("Nothing"))
                        MaterialTheme.colorScheme.onSurface
                    else MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            // ── Settings ──────────────────────────────────────────────────────
            HorizontalDivider()
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Settings", style = MaterialTheme.typography.titleMedium)
                TextButton(onClick = { showSettings = !showSettings }) {
                    Text(if (showSettings) "Hide" else "Show")
                }
            }

            if (showSettings) {
                OutlinedTextField(
                    value = serverUrl, onValueChange = { serverUrl = it },
                    label = { Text("Server URL (https://…)") },
                    singleLine = true, modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = token, onValueChange = { token = it },
                    label = { Text("Upload token") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth(),
                )
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceBetween,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text("Upload on Wi-Fi only")
                    Switch(checked = wifiOnly, onCheckedChange = { wifiOnly = it })
                }
                Button(
                    onClick = { if (saveSettings()) showSettings = false },
                    modifier = Modifier.fillMaxWidth().height(56.dp),
                ) { Text("Save settings") }
            }
        }
    }

    @Composable
    private fun CameraCard(treeUri: String?, onPick: () -> Unit) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = if (treeUri != null)
                    MaterialTheme.colorScheme.primaryContainer
                else
                    MaterialTheme.colorScheme.surfaceVariant,
            ),
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                if (treeUri == null) {
                    Text("Camera not connected", style = MaterialTheme.typography.titleMedium)
                    Text(
                        "Plug in your camera via USB, then choose the DCIM folder.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                    Button(onClick = onPick, modifier = Modifier.fillMaxWidth().height(52.dp)) {
                        Text("Choose DCIM folder")
                    }
                } else {
                    Text("Camera ready", style = MaterialTheme.typography.titleMedium)
                    TextButton(onClick = onPick, modifier = Modifier.padding(top = 0.dp)) {
                        Text("Change folder")
                    }
                }
            }
        }
    }

    @Composable
    private fun StatusCard(
        isScanning: Boolean, isWorkerRunning: Boolean, isWorkerQueued: Boolean,
        wifiOnly: Boolean, total: Int, pending: Int, uploading: Int, done: Int, failed: Int,
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = when {
                    failed > 0 -> MaterialTheme.colorScheme.errorContainer
                    pending == 0 && !isWorkerRunning && done > 0 -> MaterialTheme.colorScheme.primaryContainer
                    else -> MaterialTheme.colorScheme.surfaceVariant
                },
            ),
        ) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (isScanning || isWorkerRunning) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                    }
                    Text(
                        when {
                            isScanning -> "Scanning card…"
                            isWorkerRunning && uploading == 0 -> "Checking for duplicates…"
                            isWorkerRunning -> "Uploading…"
                            isWorkerQueued -> if (wifiOnly) "Waiting for Wi-Fi…" else "Upload queued…"
                            pending == 0 && failed == 0 -> "All done"
                            failed > 0 -> "$failed file(s) failed"
                            else -> "$pending file(s) pending"
                        },
                        style = MaterialTheme.typography.titleMedium,
                    )
                }
                if (isWorkerRunning && total > 0) {
                    LinearProgressIndicator(
                        progress = { done.toFloat() / total },
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Text("$done / $total", style = MaterialTheme.typography.bodySmall)
                }
                Row(horizontalArrangement = Arrangement.spacedBy(16.dp)) {
                    if (done > 0) Text("✓ $done", style = MaterialTheme.typography.labelMedium)
                    if (pending > 0) Text("⏳ $pending", style = MaterialTheme.typography.labelMedium)
                    if (uploading > 0) Text("↑ $uploading", style = MaterialTheme.typography.labelMedium)
                    if (failed > 0) Text(
                        "✗ $failed",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}
