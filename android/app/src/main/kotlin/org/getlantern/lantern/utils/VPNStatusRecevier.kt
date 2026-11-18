package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import lantern.io.mobile.Mobile
import org.getlantern.lantern.service.LanternVpnService
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
                onDeviceIdleChanged(idle)
            }
        }
    }

    companion object {
        // One thread keeps pause and wake in order and off the main thread:
        // the tunnel's lock can be held for seconds while it connects.
        private val idleExecutor = Executors.newSingleThreadExecutor()

        /**
         * Pauses the tunnel's background work, such as server probes, while
         * the device is in Doze, and wakes it after.
         */
        fun onDeviceIdleChanged(idle: Boolean) {
            AppLogger.i("VPNStatus", "Device idle mode changed: idle=$idle")
            idleExecutor.execute {
                if (idle) Mobile.devicePause() else Mobile.deviceWake()
            }
        }
    }
}
