package org.getlantern.lantern.utils

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FlutterEventListenerTest {
    @Test
    fun snapshotsAndOtherFrequentEventsStayOutOfTheLogFile() {
        for (type in listOf("unbounded-snapshot", "peer-snapshot", "peer-connection", "data-cap-event")) {
            assertTrue(type, FlutterEventListener.isHighVolume(type))
        }
    }

    @Test
    fun otherEventsAreLogged() {
        for (type in listOf("helper-live", "selection-changed", "server-location", "unbounded-unavailable")) {
            assertFalse(type, FlutterEventListener.isHighVolume(type))
        }
    }
}
