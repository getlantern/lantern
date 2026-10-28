package org.getlantern.lantern.utils

import org.junit.Assert.assertEquals
import org.junit.Test

class HelperTagsTest {
    private val tag = "helper-0123456789ab"

    @Test
    fun redactsEveryHelperTag() {
        assertEquals(
            "outbound/samizdat[helper] and helper",
            HelperTags.redact("outbound/samizdat[$tag] and helper-ffffffffffff"),
        )
        assertEquals("helper_failed", HelperTags.redact("${tag}_failed"))
    }

    @Test
    fun leavesOtherTextAlone() {
        assertEquals("helper-short stays", HelperTags.redact("helper-short stays"))
        assertEquals("x$tag", HelperTags.redact("x$tag"))
    }

    @Test
    fun serverLocationEventsLogOnlyTheirType() {
        val message = """{"tag":"$tag","location":{"city":"Berlin"}}"""
        assertEquals("server-location", HelperTags.loggableEvent("server-location", message))
    }

    @Test
    fun otherEventsLogARedactedMessage() {
        assertEquals("config - using helper", HelperTags.loggableEvent("config", "using $tag"))
    }
}
