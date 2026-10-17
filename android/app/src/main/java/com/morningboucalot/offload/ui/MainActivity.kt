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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
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
import com.morningboucalot.offload.data.OffloadDatabase
import com.morningboucalot.offload.scan.CardScanner
import com.morningboucalot.offload.scan.ScanCard
import com.morningboucalot.offload.settings.Settings
import com.morningboucalot.offload.upload.UploadScheduler
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/** Pick the card folder, save the server settings, scan, and upload; per-status counts show progress. */
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
        var treeUri by remember { mutableStateOf(settings.treeUri) }
        var serverUrl by remember { mutableStateOf(settings.serverUrl) }
        var token by remember { mutableStateOf(settings.token) }
        var wifiOnly by remember { mutableStateOf(settings.wifiOnly) }
        var message by remember { mutableStateOf("") }
        val counts by dao.counts().collectAsState(initial = emptyList())

        val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            if (uri != null) {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                settings.treeUri = uri.toString()
                treeUri = uri.toString()
            }
        }
        // The upload runs either way; the permission only decides whether its progress notification is visible.
        val notificationPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {}

        fun saveSettings(): Boolean {
            val url = serverUrl.trim().toHttpUrlOrNull()
            if (url == null || !url.isHttps) {
                message = "Server URL must start with https://"
                return false
            }
            if (token.isBlank()) {
                message = "Enter the upload token"
                return false
            }
            settings.serverUrl = url.toString()
            serverUrl = url.toString()
            settings.token = token.trim()
            settings.wifiOnly = wifiOnly
            return true
        }

        fun startUpload() {
            if (!saveSettings()) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
            ) {
                notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
            UploadScheduler.enqueue(this, wifiOnly)
            message = if (wifiOnly) "Upload queued (waits for Wi-Fi)" else "Upload queued"
        }

        Column(
            modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Boucalot Offload", style = MaterialTheme.typography.headlineSmall)

            Text("Card", style = MaterialTheme.typography.titleMedium)
            Text(treeUri ?: "No card folder chosen yet")
            OutlinedButton(onClick = { folderPicker.launch(null) }, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                Text("Choose card folder (DCIM)")
            }

            Text("Server", style = MaterialTheme.typography.titleMedium)
            OutlinedTextField(
                value = serverUrl,
                onValueChange = { serverUrl = it },
                label = { Text("Server URL (https://…)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            OutlinedTextField(
                value = token,
                onValueChange = { token = it },
                label = { Text("Upload token") },
                singleLine = true,
                visualTransformation = PasswordVisualTransformation(),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween,
                modifier = Modifier.fillMaxWidth()) {
                Text("Upload on Wi-Fi only")
                Switch(checked = wifiOnly, onCheckedChange = { wifiOnly = it })
            }

            Button(
                enabled = treeUri != null,
                onClick = {
                    if (!saveSettings()) return@Button
                    scope.launch {
                        val uri = Uri.parse(treeUri)
                        val plan = withContext(Dispatchers.IO) {
                            ScanCard({ CardScanner(this@MainActivity).list(uri) }, dao).run()
                        }
                        message = "Queued ${plan.toQueue.size}, already known ${plan.alreadyKnown}, " +
                            "still being written ${plan.unstable}"
                        if (plan.toQueue.isNotEmpty()) startUpload()
                    }
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
            ) { Text("Scan card & upload") }

            OutlinedButton(onClick = { startUpload() }, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                Text("Retry pending uploads")
            }

            if (message.isNotEmpty()) Text(message)
            counts.forEach { Text("${it.status}: ${it.count}") }
        }
    }
}
