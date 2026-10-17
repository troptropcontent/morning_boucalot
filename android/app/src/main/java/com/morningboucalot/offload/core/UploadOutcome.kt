package com.morningboucalot.offload.core

/** What to do with a file after the server answered (or didn't). */
sealed interface UploadOutcome {
    data object Uploaded : UploadOutcome
    data object Duplicate : UploadOutcome

    /** Retrying won't help (unsupported type, bad request). */
    data class PermanentFailure(val reason: String) : UploadOutcome

    /** Bad or missing token: retrying won't help until the user fixes settings. */
    data object AuthFailure : UploadOutcome

    /** Network trouble or server-side error: try again later. */
    data class Retry(val reason: String) : UploadOutcome

    companion object {
        fun fromStatus(code: Int): UploadOutcome = when (code) {
            201 -> Uploaded
            200 -> Duplicate
            401 -> AuthFailure
            400, 422 -> PermanentFailure("rejected by server ($code)")
            else -> Retry("server answered $code")
        }
    }
}
