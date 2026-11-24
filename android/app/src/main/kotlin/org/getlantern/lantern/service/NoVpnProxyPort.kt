package org.getlantern.lantern.service

import android.content.Context
import org.getlantern.lantern.BuildConfig

/**
 * The listen port of the no-VPN local proxy. The user's choice is kept in
 * native preferences because Android can restart the sticky proxy service
 * after a process kill without running Flutter, which would otherwise leave
 * the listener on the default port.
 */
object NoVpnProxyPort {
    private const val PREFS_NAME = "local_connection"
    private const val KEY_LISTEN_PORT = "listen_port"

    /** Saves [port]; a value outside 1..65535 clears the override. */
    fun save(context: Context, port: Int) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        if (port in 1..65535) {
            prefs.putInt(KEY_LISTEN_PORT, port)
        } else {
            prefs.remove(KEY_LISTEN_PORT)
        }
        prefs.apply()
    }

    fun get(context: Context): Int {
        val port = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_LISTEN_PORT, 0)
        return if (port in 1..65535) port else BuildConfig.STEALTH_NO_VPN_PROXY_PORT
    }
}
