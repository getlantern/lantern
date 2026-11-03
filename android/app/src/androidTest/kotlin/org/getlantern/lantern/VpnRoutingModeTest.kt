package org.getlantern.lantern

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Message
import android.os.Messenger
import android.os.Process
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
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Checks that traffic leaves through a proxy in both routing modes. The public
 * IP is read by [PublicIpProbeService]: Lantern excludes its own process from
 * the VPN, so a check from inside the app never sees the tunnel.
 */
@RunWith(AndroidJUnit4::class)
class VpnRoutingModeTest {
    private val instrumentation = InstrumentationRegistry.getInstrumentation()
    private val context = instrumentation.targetContext
    private var smartRouting = true

    @JvmField
    @Rule
    val activity = ActivityTestRule(MainActivity::class.java, true, false)

    @Before
    fun prepare() {
        grantVpnConsent()
        grantNotificationPermission()
        activity.launchActivity(Intent())
        startService(LanternVpnService.ACTION_START_RADIANCE)
        await("Radiance ready") { Mobile.isRadianceConnected() }
        smartRouting = Mobile.isSmartRoutingEnabled()
    }

    @After
    fun cleanup() {
        if (!Mobile.isRadianceConnected()) return
        try {
            disconnect()
        } finally {
            Mobile.setSmartRoutingEnabled(smartRouting)
        }
    }

    @Test(timeout = 300_000)
    fun publicIpChangesInEachRoutingMode() {
        val directIp = awaitProbe("direct traffic before connecting") {
            !it.getBoolean(PublicIpProbeService.VPN)
        }.getString(PublicIpProbeService.IP)

        for (smart in listOf(false, true)) {
            val mode = if (smart) "smart routing" else "full tunnel"
            Mobile.setSmartRoutingEnabled(smart)
            startService(LanternVpnService.ACTION_START_VPN)
            await("VPN connected in $mode") { Mobile.isVPNConnected() }
            val tunneled = awaitProbe("proxied traffic in $mode") {
                it.getBoolean(PublicIpProbeService.VPN)
            }
            assertNotEquals("Public IP did not change in $mode", directIp, tunneled.getString(PublicIpProbeService.IP))

            disconnect()
            awaitProbe("direct traffic after $mode") { !it.getBoolean(PublicIpProbeService.VPN) }
        }
    }

    private fun startService(action: String) {
        context.startService(Intent(context, LanternVpnService::class.java).setAction(action))
    }

    private fun disconnect() {
        Mobile.stopVPN()
        startService(LanternVpnService.ACTION_STOP_VPN)
        await("VPN disconnected") { !Mobile.isVPNConnected() }
    }

    // Probes fail while the network switches, so they are retried with the condition.
    private fun awaitProbe(description: String, condition: (Bundle) -> Boolean): Bundle {
        val deadline = SystemClock.elapsedRealtime() + 60_000
        var last = Bundle()
        while (SystemClock.elapsedRealtime() < deadline) {
            last = probe()
            val ip = last.getString(PublicIpProbeService.IP).orEmpty()
            if (!last.containsKey(PublicIpProbeService.ERROR) && Patterns.IP_ADDRESS.matcher(ip).matches() && condition(last)) {
                return last
            }
            SystemClock.sleep(1_000)
        }
        throw AssertionError(
            "Timed out waiting for $description; last probe: vpn=${last.getBoolean(PublicIpProbeService.VPN)} " +
                "ip=${last.getString(PublicIpProbeService.IP)} error=${last.getString(PublicIpProbeService.ERROR)}",
        )
    }

    private fun probe(): Bundle {
        val received = ArrayBlockingQueue<Bundle>(1)
        // A framework Messenger, not a ResultReceiver subclass: the probe's
        // process can't load this test's classes to unparcel one.
        val reply = Messenger(Handler(Looper.getMainLooper()) { message ->
            received.offer(Bundle(message.data))
            true
        })
        val connected = ArrayBlockingQueue<Messenger>(1)
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName, binder: IBinder) {
                connected.offer(Messenger(binder))
            }

            override fun onServiceDisconnected(name: ComponentName) = Unit
        }
        val intent = Intent().setComponent(
            ComponentName(instrumentation.context.packageName, PublicIpProbeService::class.java.name),
        )
        val bound = context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        try {
            assertTrue("Could not bind probe service", bound)
            val messenger = connected.poll(10, TimeUnit.SECONDS)
            assertNotNull("Probe service did not connect", messenger)
            requireNotNull(messenger).send(Message.obtain().apply { replyTo = reply })
            val result = requireNotNull(received.poll(25, TimeUnit.SECONDS)) { "Probe service did not reply" }
            assertNotEquals("Probe must run outside Lantern's UID", Process.myUid(), result.getInt(PublicIpProbeService.UID))
            return result
        } finally {
            context.unbindService(connection)
        }
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
