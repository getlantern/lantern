package org.getlantern.lantern.apps

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AppFiltersTest {
    private val ownPkg = "org.getlantern.lantern"

    @Test
    fun hidesTunnelBypassApps() {
        AppFilters.TUNNEL_BYPASS.forEach { pkg ->
            assertTrue(pkg, AppFilters.shouldSkip(pkg, ownPkg))
        }
    }

    @Test
    fun hidesLanternItself() {
        assertTrue(AppFilters.shouldSkip(ownPkg, ownPkg))
    }

    @Test
    fun keepsOrdinaryUserApps() {
        assertFalse(AppFilters.shouldSkip("com.example.app", ownPkg))
        assertFalse(AppFilters.shouldSkip("com.android.chrome", ownPkg))
    }

    @Test
    fun hidesSystemApps() {
        assertTrue(AppFilters.shouldSkip("com.android.settings", ownPkg))
        assertTrue(AppFilters.shouldSkip("com.miui.home", ownPkg))
    }
}
