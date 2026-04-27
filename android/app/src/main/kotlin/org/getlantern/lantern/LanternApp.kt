package org.getlantern.lantern

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

    /**
     * Reads QA-only Android system properties and pushes them into the
     * radiance process environment via a gomobile-exposed setter. Must run
     * before any Mobile.setupRadiance / Mobile.startIPCServer call so the
     * Go side picks them up at init time.
     *
     * Set with adb: e.g.
     *   adb shell setprop debug.lantern.outbound_socks 10.0.2.2:1080
     *   adb shell setprop debug.lantern.tz Europe/Moscow
     *
     * No-op when neither property is set, so production builds aren't
     * affected unless someone deliberately sets the props on the device.
     */
    private fun applyQAEnvOverrides() {
        val outboundSocks = systemProp("debug.lantern.outbound_socks")
        val tz = systemProp("debug.lantern.tz")
        if (outboundSocks.isEmpty() && tz.isEmpty()) return
        try {
            Mobile.setQAEnvOverrides(outboundSocks, tz)
            Log.i(TAG, "QA env overrides applied: outbound_socks=$outboundSocks tz=$tz")
        } catch (e: Throwable) {
            Log.e(TAG, "Failed to apply QA env overrides", e)
        }
    }

    /**
     * Reads an Android system property via reflection on android.os.SystemProperties.
     * Returns "" if the property is unset or the call fails (e.g. policy denies it).
     */
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
