package org.getlantern.lantern.service

import android.net.VpnService
import lantern.io.libbox.Notification

class VpnService : VpnService(), PlatformInterfaceWrapper {

    

    override fun sendNotification(p0: Notification?) {
        TODO("Not yet implemented")
    }

    override fun writeLog(p0: String?) {
        TODO("Not yet implemented")
    }
}