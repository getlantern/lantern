package org.getlantern.lantern.utils

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.getlantern.lantern.service.LanternVpnService

class VPNStatusReceiver(private val service: LanternVpnService) : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        when (intent?.action) {
            LanternVpnService.ACTION_START_RADIANCE -> {
            }

            LanternVpnService.ACTION_START_VPN -> {
                Log.d("VPNStatus", "VPN Started")

            }

            LanternVpnService.ACTION_STOP_VPN -> {
                Log.d("VPNStatus", "Stopping VPN")
                LanternVpnService.instance.doStopVPN()

            }

            else -> {
                //todo unimplemented
            }
        }
    }
}