package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import lantern.io.mobile.Mobile
import org.getlantern.lantern.LanternApp
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
                AppLogger.i("VPNStatus", "Device idle mode changed: idle=${isDeviceIdle()}")
                deviceIdle.reconcile()
            }
        }
    }

    companion object {
        private fun isDeviceIdle(): Boolean =
            LanternApp.application.getSystemService(PowerManager::class.java)
                ?.isDeviceIdleMode == true

        val deviceIdle = DeviceIdleForwarder(
            Executors.newSingleThreadExecutor(),
            isIdle = ::isDeviceIdle,
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
    private val isIdle: () -> Boolean,
    private val pause: () -> Unit,
    private val wake: () -> Unit,
) {
    /**
     * Applies the device's idle state as of when the task runs, not when it
     * was queued, so a late task cannot undo a newer change. Pause and wake
     * are idempotent, so a redundant one does nothing.
     */
    fun reconcile() {
        executor.execute { if (isIdle()) pause() else wake() }
    }
}
