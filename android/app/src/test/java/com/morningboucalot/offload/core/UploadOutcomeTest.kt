package com.morningboucalot.offload.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class UploadOutcomeTest {
    @Test fun `201 is uploaded and 200 is duplicate`() {
        assertEquals(UploadOutcome.Uploaded, UploadOutcome.fromStatus(201))
        assertEquals(UploadOutcome.Duplicate, UploadOutcome.fromStatus(200))
    }

    @Test fun `401 is an auth failure`() {
        assertEquals(UploadOutcome.AuthFailure, UploadOutcome.fromStatus(401))
    }

    @Test fun `400 and 422 fail permanently`() {
        assertTrue(UploadOutcome.fromStatus(400) is UploadOutcome.PermanentFailure)
        assertTrue(UploadOutcome.fromStatus(422) is UploadOutcome.PermanentFailure)
    }

    @Test fun `server errors and anything unexpected are retried`() {
        assertTrue(UploadOutcome.fromStatus(500) is UploadOutcome.Retry)
        assertTrue(UploadOutcome.fromStatus(503) is UploadOutcome.Retry)
        assertTrue(UploadOutcome.fromStatus(302) is UploadOutcome.Retry)
    }
}
