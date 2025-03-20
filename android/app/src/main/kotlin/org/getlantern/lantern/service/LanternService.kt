package org.getlantern.lantern.service

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import lantern.io.libbox.Notification
import lantern.io.mobile.Mobile
import lantern.io.radiance.Radiance

open class LanternService : Service(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "LanternService"

    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        CoroutineScope(Dispatchers.IO).launch {
            startRadiance()
        }
        return START_NOT_STICKY
    }

    private fun startRadiance() {
        try {
            Mobile.setupRadiance(this)
            Log.d(TAG, "Radiance setup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error in Radiance setup", e)
        }
    }

    override fun onBind(p0: Intent?): IBinder? {
        return null
    }

    override fun sendNotification(p0: Notification?) {
        TODO("Not yet implemented")
    }

    override fun writeLog(p0: String?) {
        TODO("Not yet implemented")
    }

}