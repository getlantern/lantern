package org.getlantern.lantern

import android.Manifest
import android.content.ComponentName
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.os.Process
import android.os.ResultReceiver
import android.os.SystemClock
import android.util.Patterns
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.rule.ActivityTestRule
import androidx.test.runner.AndroidJUnit4
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.TimeUnit
import lantern.io.mobile.Mobile
import org.getlantern.lantern.service.LanternVpnService
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
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
        val baseline = probe()
        assertFalse(baseline.getBoolean("vpn"))
        val directIP = baseline.getString("ip")
        Mobile.addSplitTunnelItem("packageName", probePackage)
        Mobile.setSplitTunnelingEnabled(true)
        context.startService(Intent(context, LanternVpnService::class.java).setAction(LanternVpnService.ACTION_START_VPN))
        await("VPN connected") { Mobile.isVPNConnected() }
        assertProbe(vpn = false, ip = directIP)

        Mobile.switchSplitTunnelPolicy("include")
        Mobile.addSplitTunnelItem("packageName", probePackage)
        val included = assertProbe(vpn = true)
        assertNotEquals("Selected app must use a proxy exit", directIP, included.getString("ip"))

        Mobile.clearSplitTunnelApps()
        assertProbe(vpn = false, ip = directIP)
        Mobile.addSplitTunnelItem("packageName", "org.getlantern.split.smoke.missing")
        assertProbe(vpn = false, ip = directIP)

        Mobile.addSplitTunnelItem("domainSuffix", "api.ipify.org")
        val mixed = assertProbe(vpn = true)
        assertNotEquals("A selected website in an unselected app must use the proxy", directIP, mixed.getString("ip"))
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

    private fun assertProbe(vpn: Boolean, ip: String? = null): Bundle {
        var result = Bundle()
        await("probe VPN=$vpn, IP=$ip") {
            result = probe()
            result.getBoolean("vpn") == vpn && (ip == null || result.getString("ip") == ip)
        }
        assertEquals(vpn, result.getBoolean("vpn"))
        return result
    }

    private fun probe(): Bundle {
        val received = ArrayBlockingQueue<Bundle>(1)
        val reply = object : ResultReceiver(Handler(Looper.getMainLooper())) {
            override fun onReceiveResult(resultCode: Int, data: Bundle) {
                received.offer(data)
            }
        }
        // The test APK's service runs under its own UID, unlike instrumentation in the target process.
        context.startService(Intent().setComponent(ComponentName(probePackage, SplitTunnelProbeService::class.java.name)).putExtra("reply", reply))
        val result = received.poll(25, TimeUnit.SECONDS)
        assertNotNull("Probe service did not reply", result)
        requireNotNull(result)
        assertNotEquals("Probe must run outside Lantern's UID", Process.myUid(), result.getInt("uid"))
        assertFalse(result.getString("error"), result.containsKey("error"))
        assertTrue("Invalid public IP: ${result.getString("ip")}", Patterns.IP_ADDRESS.matcher(result.getString("ip") ?: "").matches())
        return result
    }

    private fun await(description: String, condition: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 60_000
        while (SystemClock.elapsedRealtime() < deadline) {
            if (condition()) return
            SystemClock.sleep(250)
        }
        throw AssertionError("Timed out waiting for $description")
    }
}
