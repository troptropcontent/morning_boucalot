package com.morningboucalot.offload.core

import java.io.InputStream

/** What the upload logic needs from the server; [OffloadApi] is the real one, tests use a fake. */
interface OffloadServer {
    /** Of [checksums] (base64 MD5), the ones the server already has. */
    fun known(checksums: List<String>): Set<String>

    /** Streams [file] (read via [open]) to the server and classifies the answer. */
    fun upload(file: CardFile, open: () -> InputStream): UploadOutcome

    /** Sends a RAF straight to S3 through a server-issued presigned URL; Duplicate if S3 already has it. */
    fun uploadRaf(file: CardFile, open: () -> InputStream): UploadOutcome
}
