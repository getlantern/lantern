package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import lantern.io.mobile.Mobile
import org.getlantern.lantern.service.LanternVpnService
import java.util.concurrent.Executor
import java.util.concurrent.Executors

class VPNStatusReceiver() : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            LanternVpnService.ACTION_START_RADIANCE -> {
            }

            LanternVpnService.ACTION_START_VPN -> {
                AppLogger.d("VPNStatus", "VPN Started")
            }

            LanternVpnService.ACTION_STOP_VPN -> {
                AppLogger.d("VPNStatus", "Stopping VPN")
                LanternVpnService.instance.doStopVPN()
            }

            PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                val idle = context?.getSystemService(PowerManager::class.java)
                    ?.isDeviceIdleMode ?: return
                AppLogger.i("VPNStatus", "Device idle mode changed: idle=$idle")
                deviceIdle.onIdleChanged(idle)
            }
        }
    }

    companion object {
        val deviceIdle = DeviceIdleForwarder(
            Executors.newSingleThreadExecutor(),
            pause = { Mobile.devicePause() },
            wake = { Mobile.deviceWake() },
        )
    }
}

/**
 * Pauses the tunnel's background work, such as server probes, while the
 * device is in Doze. Calls run in order on [executor], off the main thread:
 * the tunnel's lock can be held for seconds while it connects.
 */
class DeviceIdleForwarder(
    private val executor: Executor,
    private val pause: () -> Unit,
    private val wake: () -> Unit,
) {
    fun onIdleChanged(idle: Boolean) {
        executor.execute { if (idle) pause() else wake() }
    }

    /** A new tunnel starts awake, so it needs pausing only if the device is idle. */
    fun onTunnelStarted(idle: Boolean) {
        if (idle) executor.execute { pause() }
    }
}
