package org.getlantern.lantern.service

import android.net.Network
import android.os.Build

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import lantern.io.libbox.InterfaceUpdateListener
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.utils.Bugs
import java.net.NetworkInterface

object DefaultNetworkMonitor {
    private const val TAG = "DefaultNetworkMonitor"
    var defaultNetwork: Network? = null
    private var listener: InterfaceUpdateListener? = null

    suspend fun start() {
        DefaultNetworkListener.start(this) { newNetwork ->
            handleNetworkChanged(newNetwork)
        }

        val current = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            LanternApp.connectivity.activeNetwork
        } else {
            DefaultNetworkListener.get()
        }
        handleNetworkChanged(current)
    }

    suspend fun stop() {
        DefaultNetworkListener.stop(this)
    }

    suspend fun require(): Network {
        val network = defaultNetwork
        if (network != null) {
            return network
        }
        return DefaultNetworkListener.get()
    }

    fun setListener(listener: InterfaceUpdateListener?) {
        this.listener = listener
        checkDefaultInterfaceUpdate(defaultNetwork)
    }

    private fun checkDefaultInterfaceUpdate(
        newNetwork: Network?
    ) {
        val listener = listener ?: return
        if (newNetwork != null) {
            val interfaceName =
                (LanternApp.connectivity.getLinkProperties(newNetwork) ?: return).interfaceName
            for (times in 0 until 10) {
                var interfaceIndex: Int
                try {
                    interfaceIndex = NetworkInterface.getByName(interfaceName).index
                } catch (e: Exception) {
                    Thread.sleep(100)
                    continue
                }
                if (Bugs.fixAndroidStack) {
                    GlobalScope.launch(Dispatchers.IO) {
                        listener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
                    }
                } else {
                    listener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
                }
            }
        } else {
            if (Bugs.fixAndroidStack) {
                GlobalScope.launch(Dispatchers.IO) {
                    listener.updateDefaultInterface("", -1, false, false)
                }
            } else {
                listener.updateDefaultInterface("", -1, false, false)
            }
        }
    }

    private fun handleNetworkChanged(newNetwork: Network?) {
        val previous = defaultNetwork
        defaultNetwork = newNetwork

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            try {
                val lp = newNetwork?.let { LanternApp.connectivity.getLinkProperties(it) }
                val underlying = lp?.underlyingNetworks
                val toSet: Array<Network>? = when {
                    underlying != null && underlying.isNotEmpty() -> underlying.toTypedArray()
                    newNetwork != null -> arrayOf(newNetwork)
                    else -> null
                }
                LanternVpnService.instance.setUnderlyingNetworks(toSet)
            } catch (e: Exception) {
                android.util.Log.w(TAG, "setUnderlyingNetworks failed", e)
            }
        }

        if (previous != null && newNetwork != null && previous != newNetwork) {
            try {
                if (lantern.io.mobile.Mobile.isVPNConnected()) {
                    LanternVpnService.instance.onUnderlyingNetworkChanged()
                }
            } catch (t: Throwable) {
                android.util.Log.w(TAG, "Failed to handle network change", t)
            }
        }

        checkDefaultInterfaceUpdate(newNetwork)
    }
}