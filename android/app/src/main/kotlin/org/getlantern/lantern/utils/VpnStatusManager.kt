package org.getlantern.lantern.utils

import android.content.IntentFilter
import android.os.PowerManager
import android.util.Log
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_START_VPN
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN

/**
 * Singleton to manage VPN status using LiveData.
 */
object VpnStatusManager {
    val vpnStatus = MutableLiveData<Event<VPNStatus>>()

    fun postVPNStatus(status: VPNStatus) {
        Log.d("VPNStatus", "Posting VPN status: $status")
        vpnStatus.postValue(Event(status))
    }

    fun postVPNError(errorCode: String, errorMessage: String, error: Throwable?) {
        val errorStatus = VPNStatus.error(errorCode, errorMessage, error)
        vpnStatus.postValue(Event(errorStatus))

    }

    fun registerVPNStatusReceiver(service: LanternVpnService) {
        ContextCompat.registerReceiver(
            LanternApp.application,
            VPNStatusReceiver(),
            IntentFilter().apply {
                addAction(ACTION_START_VPN)
                addAction(ACTION_STOP_VPN)
                addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
            },
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    fun unregisterVPNStatusReceiver(service: LanternVpnService) {
        try{
            // todo check if receiver is registered or not
            LanternApp.application.unregisterReceiver(VPNStatusReceiver())
        }catch (e: IllegalArgumentException){
            Log.e("VpnStatusManager", "unregisterVPNStatusReceiver: ", e)
        }

    }
}