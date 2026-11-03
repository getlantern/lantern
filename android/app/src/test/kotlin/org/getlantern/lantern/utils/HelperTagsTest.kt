package org.getlantern.lantern.utils

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
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
    fun redactsThePersonalProxiesGroupAndType() {
        assertEquals(
            "selected helper (type=helper)",
            HelperTags.redact("selected personal-proxies (type=personalProxy)"),
        )
        assertEquals("""{"tag":"helper"}""", HelperTags.redact("""{"tag":"personal-proxies"}"""))
        assertEquals("personalProxyX stays", HelperTags.redact("personalProxyX stays"))
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

    @Test
    fun redactsAFriendsSelection() {
        assertEquals(
            "connecting to helper:helper",
            HelperTags.redact("connecting to personal-proxy:$tag"),
        )
        assertEquals(
            "outbound/mutableurltest[helper]",
            HelperTags.redact("outbound/mutableurltest[personal-proxy]"),
        )
    }

    @Test
    fun redactsAThrowableAndItsCauses() {
        val cause = IllegalStateException("dial personal-proxy:$tag failed")
        val error = RuntimeException("outbound/samizdat[$tag]: refused", cause)
        val text = HelperTags.redactWithThrowable("connect failed", error)
        assertFalse(text, text.contains(tag))
        assertFalse(text, text.contains("personal-proxy"))
        assertTrue(text.startsWith("connect failed\n"))
        assertTrue(text, text.contains("outbound/samizdat[helper]: refused"))
        assertTrue(text, text.contains("dial helper:helper failed"))
        assertEquals("plain", HelperTags.redactWithThrowable("plain", null))
    }
}
