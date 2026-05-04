package org.getlantern.lantern

import android.annotation.SuppressLint
import android.app.Application
import android.content.ClipboardManager
import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.PowerManager
import android.util.Log
import androidx.core.content.getSystemService
import lantern.io.mobile.Mobile


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

    override fun onCreate() {
        super.onCreate()
        applyQAEnvOverrides()
    }

    private fun applyQAEnvOverrides() {
        if (!BuildConfig.DEVELOPMENT_MODE) return

        try {
            val outboundSocks = systemProp("debug.lantern.outbound_socks").trim()
            val tz = systemProp("debug.lantern.tz").trim()
            if (outboundSocks.isEmpty() && tz.isEmpty()) return

            Mobile.setQAEnvOverrides(outboundSocks, tz)
            Log.i(TAG, "QA env overrides applied: outbound_socks=$outboundSocks tz=$tz")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to apply QA env overrides", e)
        }
    }

    @SuppressLint("PrivateApi")
    private fun systemProp(key: String): String {
        return try {
            val cls = Class.forName("android.os.SystemProperties")
            val m = cls.getMethod("get", String::class.java, String::class.java)
            (m.invoke(null, key, "") as? String) ?: ""
        } catch (e: Throwable) {
            ""
        }
    }
}

private const val TAG = "LanternApp"
