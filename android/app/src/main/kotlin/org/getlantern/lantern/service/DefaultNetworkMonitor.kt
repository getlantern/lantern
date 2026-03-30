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

    var defaultNetwork: Network? = null
    private var listener: InterfaceUpdateListener? = null
    private var networkChangeCallback: ((Network?) -> Unit)? = null

    /**
     * Register a callback that fires whenever the default network changes.
     * Used by [LanternVpnService] to call [android.net.VpnService.setUnderlyingNetworks].
     */
    fun setNetworkChangeCallback(callback: ((Network?) -> Unit)?) {
        networkChangeCallback = callback
    }

    suspend fun start() {
        DefaultNetworkListener.start(this) {
            defaultNetwork = it
            networkChangeCallback?.invoke(it)
            checkDefaultInterfaceUpdate(it)
        }
        defaultNetwork = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            LanternApp.connectivity.activeNetwork
        } else {
            DefaultNetworkListener.get()
        }
    }

    suspend fun stop() {
        networkChangeCallback = null
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
                return // successfully notified, don't retry
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

}