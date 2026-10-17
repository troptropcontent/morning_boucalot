package com.morningboucalot.offload.ui

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.morningboucalot.offload.data.OffloadDatabase
import com.morningboucalot.offload.scan.CardScanner
import com.morningboucalot.offload.scan.ScanCard
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** Scaffold screen: pick the card folder, scan it, see per-status counts. */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { MaterialTheme { OffloadScreen() } }
    }

    @Composable
    private fun OffloadScreen() {
        val prefs = remember { getSharedPreferences("offload", MODE_PRIVATE) }
        val dao = remember { OffloadDatabase.get(this).dao() }
        val scope = rememberCoroutineScope()
        var treeUri by remember { mutableStateOf(prefs.getString(KEY_TREE_URI, null)) }
        var message by remember { mutableStateOf("") }
        val counts by dao.counts().collectAsState(initial = emptyList())

        val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri: Uri? ->
            if (uri != null) {
                contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                prefs.edit().putString(KEY_TREE_URI, uri.toString()).apply()
                treeUri = uri.toString()
            }
        }

        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("Boucalot Offload", style = MaterialTheme.typography.headlineSmall)
            Text(treeUri ?: "No card folder chosen yet")

            Button(onClick = { picker.launch(null) }, modifier = Modifier.fillMaxWidth().height(56.dp)) {
                Text("Choose card folder (DCIM)")
            }
            Button(
                enabled = treeUri != null,
                onClick = {
                    scope.launch {
                        val uri = Uri.parse(treeUri)
                        val plan = withContext(Dispatchers.IO) {
                            ScanCard({ CardScanner(this@MainActivity).list(uri) }, dao).run()
                        }
                        message = "Queued ${plan.toQueue.size}, already known ${plan.alreadyKnown}, " +
                            "still being written ${plan.unstable}"
                    }
                },
                modifier = Modifier.fillMaxWidth().height(56.dp),
            ) { Text("Scan card") }

            if (message.isNotEmpty()) Text(message)
            counts.forEach { Text("${it.status}: ${it.count}") }
        }
    }

    private companion object {
        const val KEY_TREE_URI = "tree_uri"
    }
}
