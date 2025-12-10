package org.getlantern.lantern

import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.PowerManager
import androidx.core.content.getSystemService


class LanternApp : Application() {

    companion object {
        lateinit var application: LanternApp
        val connectivity by lazy { application.getSystemService<ConnectivityManager>()!! }
        val packageManager by lazy { application.packageManager }
        val powerManager by lazy { application.getSystemService<PowerManager>()!! }
        val wifiManager by lazy { application.getSystemService<WifiManager>()!! }
        val clipboard by lazy { application.getSystemService<ClipboardManager>()!! }
    }

    override fun attachBaseContext(base: Context?) {
        super.attachBaseContext(base)
        application = this

    }


}