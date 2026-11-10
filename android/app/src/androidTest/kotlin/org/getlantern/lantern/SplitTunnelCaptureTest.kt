package org.getlantern.lantern

import android.Manifest
import android.content.Intent
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.SystemClock
import android.util.Patterns
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import androidx.test.runner.AndroidJUnit4
import lantern.io.mobile.Mobile
import org.getlantern.lantern.service.LanternVpnService
import org.junit.After
import org.junit.Assert.assertNotEquals
import org.junit.Assume.assumeTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SplitTunnelCaptureTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private val probePackage = instrumentation.context.packageName
    private var selected = false
    private var smartRouting = false

    @JvmField
    @Rule
    val activity = ActivityTestRule(MainActivity::class.java, true, false)

    @Before
    fun prepare() {
        assumeTrue(InstrumentationRegistry.getArguments().getString("class") == javaClass.name)
        selected = true
        val consent = instrumentation.uiAutomation.executeShellCommand("appops set ${context.packageName} ACTIVATE_VPN allow")
        ParcelFileDescriptor.AutoCloseInputStream(consent).use { it.readBytes() }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            instrumentation.uiAutomation.grantRuntimePermission(context.packageName, Manifest.permission.POST_NOTIFICATIONS)
        }
        activity.launchActivity(Intent())
        context.startService(Intent(context, LanternVpnService::class.java).setAction(LanternVpnService.ACTION_START_RADIANCE))
        await("Radiance ready") { Mobile.isRadianceConnected() }
        smartRouting = Mobile.isSmartRoutingEnabled()
        Mobile.setSmartRoutingEnabled(false)
        Mobile.setSplitTunnelingEnabled(false)
        Mobile.switchSplitTunnelPolicy("include")
        Mobile.switchSplitTunnelPolicy("exclude")
    }

    @After
    fun cleanup() {
        if (!selected || !Mobile.isRadianceConnected()) return
        try {
            Mobile.stopVPN()
            context.startService(Intent(context, LanternVpnService::class.java).setAction(LanternVpnService.ACTION_STOP_VPN))
            await("VPN disconnected") { !Mobile.isVPNConnected() }
        } finally {
            Mobile.setSplitTunnelingEnabled(false)
            Mobile.switchSplitTunnelPolicy("include")
            Mobile.switchSplitTunnelPolicy("exclude")
            Mobile.setSmartRoutingEnabled(smartRouting)
        }
    }

    @Test(timeout = 300_000)
    fun appCaptureAndWebsiteTransitions() {
        val directIP = assertProbe(vpn = false)[PublicIpProbeService.IP] as String
        Mobile.addSplitTunnelItem("packageName", probePackage)
        Mobile.setSplitTunnelingEnabled(true)
        context.startService(Intent(context, LanternVpnService::class.java).setAction(LanternVpnService.ACTION_START_VPN))
        await("VPN connected") { Mobile.isVPNConnected() }
        assertProbe(vpn = false, ip = directIP)

        Mobile.switchSplitTunnelPolicy("include")
        Mobile.addSplitTunnelItem("packageName", probePackage)
        val included = assertProbe(vpn = true)
        assertNotEquals("Selected app must use a proxy exit", directIP, included[PublicIpProbeService.IP])

        Mobile.clearSplitTunnelApps()
        assertProbe(vpn = false, ip = directIP)
        Mobile.addSplitTunnelItem("packageName", "org.getlantern.split.smoke.missing")
        assertProbe(vpn = false, ip = directIP)

        Mobile.addSplitTunnelItem("domainSuffix", "api.ipify.org")
        val mixed = assertProbe(vpn = true)
        assertNotEquals("A selected website in an unselected app must use the proxy", directIP, mixed[PublicIpProbeService.IP])
        Mobile.addSplitTunnelItem("domainSuffix", "example.com")
        Mobile.removeSplitTunnelItem("domainSuffix", "example.com")
        assertProbe(vpn = true)
        Mobile.removeSplitTunnelItem("domainSuffix", "api.ipify.org")
        assertProbe(vpn = false, ip = directIP)

        Mobile.switchSplitTunnelPolicy("exclude")
        Mobile.addSplitTunnelItem("domainSuffix", "api.ipify.org")
        assertProbe(vpn = true, ip = directIP)
        Mobile.addSplitTunnelItem("packageName", probePackage)
        assertProbe(vpn = false, ip = directIP)
    }

    // Retries until the probe agrees; a probe error during a VPN transition is not a result.
    private fun assertProbe(vpn: Boolean, ip: String? = null): Map<String, Any?> {
        var result = emptyMap<String, Any?>()
        await("probe VPN=$vpn, IP=$ip", { "last probe: $result" }) {
            result = probePublicIp(context, probePackage)
            val exit = result[PublicIpProbeService.IP] as? String
            result[PublicIpProbeService.ERROR] == null && exit != null &&
                Patterns.IP_ADDRESS.matcher(exit).matches() &&
                result[PublicIpProbeService.VPN] == vpn && (ip == null || exit == ip)
        }
        return result
    }

    private fun await(description: String, detail: () -> String = { "" }, condition: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 60_000
        while (SystemClock.elapsedRealtime() < deadline) {
            if (condition()) return
            SystemClock.sleep(250)
        }
        throw AssertionError("Timed out waiting for $description ${detail()}".trim())
    }
}
