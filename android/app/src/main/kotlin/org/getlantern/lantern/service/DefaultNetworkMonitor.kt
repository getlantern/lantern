package org.getlantern.lantern.service

import android.net.Network
import android.os.Build

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import lantern.io.libbox.InterfaceUpdateListener
import lantern.io.mobile.Mobile
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.utils.AppLogger
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
        AppLogger.i(TAG, "Default network changed: $newNetwork")
        val previous = defaultNetwork
        /// No-op if nothing changed
        if (previous == newNetwork) {
            AppLogger.i(TAG, "Default network same as before, no-op")
            checkDefaultInterfaceUpdate(newNetwork)
            return
        }
        /// Update the default network
        defaultNetwork = newNetwork
        AppLogger.i(TAG, "Updated default network to: $defaultNetwork")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            try {
                val networksToSet: Array<Network>? =
                    newNetwork?.let { arrayOf(it) }
                AppLogger.i(
                    TAG,
                    "Setting underlying networks to: ${networksToSet?.contentToString() ?: "null"}"
                )
                LanternVpnService.instance.setUnderlyingNetworks(networksToSet)
            } catch (e: Exception) {
                AppLogger.w(TAG, "setUnderlyingNetworks failed", e)
            }
        }
        if (previous != null && newNetwork != null) {
            try {
                if (Mobile.isVPNConnected()) {
                    AppLogger.i(TAG, "Notifying LanternVpnService of underlying network change")
                    LanternVpnService.instance.onUnderlyingNetworkChanged()
                }
            } catch (t: Throwable) {
                AppLogger.w(TAG, "Failed to handle network change", t)
            }
        }
        checkDefaultInterfaceUpdate(newNetwork)
    }
}