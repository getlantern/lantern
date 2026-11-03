package org.getlantern.lantern

import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.util.Log
import androidx.test.platform.app.InstrumentationRegistry
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "LanternNetDiag"
private val started = AtomicBoolean(false)

/**
 * Logs every network change for the rest of the instrumentation run, VPNs
 * included, so Test Lab logcats show what the app's network looked like when a
 * backend call failed. Lantern's own process stays on the underlying network.
 */
internal fun logNetworkChanges() {
    if (!started.compareAndSet(false, true)) return
    val connectivity = InstrumentationRegistry.getInstrumentation().targetContext
        .getSystemService(ConnectivityManager::class.java)
    val callback = { label: String ->
        object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) =
                log(label, "available $network")

            override fun onLost(network: Network) =
                log(label, "lost $network")

            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) =
                log(label, "capabilities $network vpn=${capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)} " +
                    "validated=${capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)} $capabilities")

            override fun onLinkPropertiesChanged(network: Network, properties: LinkProperties) =
                log(label, "link $network iface=${properties.interfaceName} dns=${properties.dnsServers} " +
                    "privateDns=${properties.isPrivateDnsActive}/${properties.privateDnsServerName}")
        }
    }
    connectivity.registerDefaultNetworkCallback(callback("default"))
    connectivity.registerNetworkCallback(
        NetworkRequest.Builder()
            .removeCapability(NetworkCapabilities.NET_CAPABILITY_NOT_VPN)
            .build(),
        callback("all"),
    )
}

private fun log(label: String, message: String) {
    Log.i(TAG, "[$label] $message")
}
