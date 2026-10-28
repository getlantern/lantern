package org.getlantern.lantern.service

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class VpnAppCaptureTest {
    private val self = "lantern"
    private val installed = mutableMapOf(self to 10, "selected" to 20, "shared" to 20, "selfAlias" to 10, "other" to 30)
    private val allowed = mutableListOf<String>()
    private val disallowed = mutableListOf<String>()

    private fun apply(include: List<String>, exclude: List<String>, disappearing: String? = null) {
        VpnAppCapture(include, exclude).apply(self, 10, installed::get,
            allow = { pkg -> if (pkg == disappearing) false else { allowed.add(pkg); true } },
            disallow = { pkg -> disallowed.add(pkg); true },
        )
    }

    @Test
    fun bypassDisallowsSelectedAndSelfOnly() {
        apply(emptyList(), listOf("selected", "shared", "selfAlias", "removed"))
        assertEquals(listOf(self, "selected"), disallowed)
        assertTrue(allowed.isEmpty())
    }

    @Test
    fun includeUsesOnlyAllowedPackagesAndNeverTheOwnUid() {
        apply(listOf("selected", "selected", "shared", "selfAlias", "removed"), emptyList())
        assertEquals(listOf("selected"), allowed)
        assertTrue(disallowed.isEmpty())
    }

    @Test
    fun emptyAndMissingPackagesDoNotBecomeCaptureAll() {
        for (selection in listOf(listOf("@none"), listOf("removed"), listOf("selfAlias"))) {
            allowed.clear()
            apply(selection, emptyList())
            assertEquals(listOf(self), allowed)
            assertTrue(disallowed.isEmpty())
        }
    }

    @Test
    fun removalBetweenLookupAndBuilderStillHasEmptyFallback() {
        apply(listOf("selected"), emptyList(), disappearing = "selected")
        assertEquals(listOf(self), allowed)
        assertTrue(disallowed.isEmpty())
    }

    @Test
    fun newUnselectedAppsStayOutOfIncludeAndReinstalledSelectionsReturn() {
        val policy = VpnAppCapture(listOf("removed"), emptyList())
        assertTrue(policy.contains("removed"))
        assertFalse(policy.contains("new.app"))
        installed["new.app"] = 40
        apply(listOf("removed"), emptyList())
        assertEquals(listOf(self), allowed)
        allowed.clear()
        installed["removed"] = 50
        apply(listOf("removed"), emptyList())
        assertEquals(listOf("removed"), allowed)
    }

    @Test
    fun mixedCaptureExcludesOnlySelfAndCapturesNewApps() {
        apply(emptyList(), emptyList())
        assertTrue(allowed.isEmpty())
        assertEquals(listOf(self), disallowed)
    }

    @Test(expected = IllegalArgumentException::class)
    fun allowAndDisallowCannotBeCombined() {
        VpnAppCapture(listOf("selected"), listOf("other"))
    }

    @Test(expected = IllegalStateException::class)
    fun emptyFallbackFailureDoesNotSilentlyCaptureAll() {
        VpnAppCapture(listOf("@none"), emptyList()).apply(self, 10, installed::get, { false }, { true })
    }
}
