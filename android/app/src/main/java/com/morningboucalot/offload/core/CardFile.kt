package com.morningboucalot.offload.core

/** A file found on the camera card. [uri] is the SAF document URI used to read it later. */
data class CardFile(
    val folder: String,
    val name: String,
    val size: Long,
    val lastModified: Long,
    val uri: String,
) {
    /**
     * Identity for "already offloaded?". Folder is included because the X-E5
     * rolls to a new folder (100_FUJI, 101_FUJI, ...) when the frame counter
     * wraps after 9999; size guards against a camera reset reusing a name.
     */
    val key: String get() = "$folder/$name/$size"

    val extension: String get() = name.substringAfterLast('.', "").lowercase()
}
