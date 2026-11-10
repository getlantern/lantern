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

    // Every app enters the tunnel, so the exit IP shows whether the rules sent it direct or through a proxy.
    @Test(timeout = 300_000)
    fun appAndWebsiteRouting() {
        directIP = probe("direct IP before connecting") { _, vpn -> !vpn }
        Mobile.addSplitTunnelItem("packageName", probePackage)
        Mobile.setSplitTunnelingEnabled(true)
        context.startService(Intent(context, LanternVpnService::class.java).setAction(LanternVpnService.ACTION_START_VPN))
        await("VPN connected") { Mobile.isVPNConnected() }
        assertDirect()

        Mobile.switchSplitTunnelPolicy("include")
        assertProxied() // nothing selected yet
        Mobile.addSplitTunnelItem("packageName", probePackage)
        assertProxied()
        Mobile.clearSplitTunnelApps()
        Mobile.addSplitTunnelItem("packageName", "org.getlantern.split.smoke.missing")
        assertDirect()

        Mobile.addSplitTunnelItem("domainSuffix", "api.ipify.org")
        assertProxied()
        Mobile.addSplitTunnelItem("domainSuffix", "example.com")
        Mobile.removeSplitTunnelItem("domainSuffix", "example.com")
        assertProxied()
        Mobile.removeSplitTunnelItem("domainSuffix", "api.ipify.org")
        assertDirect()

        Mobile.switchSplitTunnelPolicy("exclude")
        assertProxied()
        Mobile.addSplitTunnelItem("domainSuffix", "api.ipify.org")
        assertDirect()
    }

    private lateinit var directIP: String

    private fun assertDirect() = probe("direct exit $directIP") { ip, vpn -> vpn && ip == directIP }

    private fun assertProxied() = probe("proxy exit") { ip, vpn -> vpn && ip != directIP }

    // Retries until the probe agrees; a probe error during a VPN transition is not a result.
    private fun probe(description: String, expected: (ip: String, vpn: Boolean) -> Boolean): String {
        var result = emptyMap<String, Any?>()
        var exit = ""
        await(description, { "last probe: $result" }) {
            result = probePublicIp(context, probePackage)
            exit = result[PublicIpProbeService.IP] as? String ?: ""
            result[PublicIpProbeService.ERROR] == null && Patterns.IP_ADDRESS.matcher(exit).matches() &&
                expected(exit, result[PublicIpProbeService.VPN] == true)
        }
        return exit
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
