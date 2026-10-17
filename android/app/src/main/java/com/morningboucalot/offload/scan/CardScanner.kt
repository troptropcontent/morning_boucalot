package com.morningboucalot.offload.scan

import android.content.Context
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import com.morningboucalot.offload.core.CardFile

/**
 * Walks the folder the user picked (via the Storage Access Framework) and
 * lists every file in it. DocumentFile does one provider query per call, so
 * a huge card is slowish; switch to DocumentsContract cursors if it hurts.
 */
class CardScanner(private val context: Context) {
    fun list(treeUri: Uri): List<CardFile> {
        val root = DocumentFile.fromTreeUri(context, treeUri) ?: return emptyList()
        return walk(root, folder = "")
    }

    private fun walk(dir: DocumentFile, folder: String): List<CardFile> =
        dir.listFiles().flatMap { entry ->
            val name = entry.name ?: return@flatMap emptyList()
            when {
                entry.isDirectory -> walk(entry, if (folder.isEmpty()) name else "$folder/$name")
                entry.isFile -> listOf(CardFile(folder, name, entry.length(), entry.lastModified(), entry.uri.toString()))
                else -> emptyList()
            }
        }
}
