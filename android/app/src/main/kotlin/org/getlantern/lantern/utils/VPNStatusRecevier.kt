package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import org.getlantern.lantern.service.LanternVpnService

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

            else -> {
                //todo unimplemented
            }
        }
    }
}