package org.getlantern.lantern

import android.app.Service
import android.content.Intent
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Messenger
import android.os.Process
import android.os.ResultReceiver
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

/**
 * Reports its public IP and whether its traffic uses a VPN. It runs in the test
 * APK's process, which Lantern's VPN covers; Lantern's own process is excluded.
 */
class PublicIpProbeService : Service() {
    private val messenger = Messenger(Handler(Looper.getMainLooper()) { message ->
        @Suppress("DEPRECATION")
        message.data.getParcelable<ResultReceiver>(REPLY)?.let(::probe)
        true
    })

    override fun onBind(intent: Intent): IBinder = messenger.binder

    private fun probe(reply: ResultReceiver) {
        thread(name = "public-ip-probe") {
            val result = Bundle().apply { putInt(UID, Process.myUid()) }
            try {
                val connectivity = getSystemService(ConnectivityManager::class.java)
                val capabilities = connectivity.getNetworkCapabilities(connectivity.activeNetwork)
                result.putBoolean(VPN, capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) == true)
                val connection = URL("https://api.ipify.org?nonce=${System.nanoTime()}")
                    .openConnection() as HttpURLConnection
                try {
                    connection.connectTimeout = 10_000
                    connection.readTimeout = 10_000
                    connection.useCaches = false
                    result.putString(IP, connection.inputStream.bufferedReader().use { it.readLine().trim() })
                } finally {
                    connection.disconnect()
                }
            } catch (e: Exception) {
                result.putString(ERROR, e.toString())
            }
            reply.send(0, result)
        }
    }

    companion object {
        const val REPLY = "reply"
        const val UID = "uid"
        const val VPN = "vpn"
        const val IP = "ip"
        const val ERROR = "error"
    }
}
