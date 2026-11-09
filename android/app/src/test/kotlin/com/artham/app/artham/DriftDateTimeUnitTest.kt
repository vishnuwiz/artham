package com.artham.app.artham

import org.junit.Assert.assertEquals
import org.junit.Test

class DriftDateTimeUnitTest {
    @Test
    fun convertsEpochMillisecondsToUnixSecondsForDrift() {
        assertEquals(
            1_700_000_123L,
            DriftDateTime.secondsFromMillis(1_700_000_123_456L),
        )
    }

    @Test
    fun dropsSubsecondPrecisionBecauseDriftDateTimeUsesSeconds() {
        assertEquals(
            1_700_000_123L,
            DriftDateTime.secondsFromMillis(1_700_000_123_999L),
        )
    }
}
