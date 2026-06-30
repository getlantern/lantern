package org.getlantern.lantern.service

import android.net.Network
import android.os.Build
import android.system.Os

import lantern.io.libbox.InterfaceUpdateListener
import org.getlantern.lantern.LanternApp
import java.net.NetworkInterface

object DefaultNetworkMonitor {
    private const val NO_INTERFACE_NAME = ""
    private const val NO_INTERFACE_INDEX = -1

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
            for (times in 0 until 10) {
                // getLinkProperties can briefly return null (or a null interfaceName)
                // right after a network change, so resolve inside the retry loop.
                val interfaceName =
                    LanternApp.connectivity.getLinkProperties(newNetwork)?.interfaceName
                if (interfaceName == null) {
                    Thread.sleep(100)
                    continue
                }
                // getByName relies on the interface-enumeration syscall, which is
                // restricted on some Android versions/ROMs (returns null or throws
                // there); Os.if_nametoindex recovers the index so the default
                // interface is still delivered, otherwise every outbound fails to bind.
                val interfaceIndex = try {
                    NetworkInterface.getByName(interfaceName)?.index ?: Os.if_nametoindex(interfaceName)
                } catch (e: Exception) {
                    0
                }
                if (interfaceIndex <= 0) {
                    Thread.sleep(100)
                    continue
                }
                // Delivered synchronously so updates apply in network-change order.
                // The golang/go#68760 stack workaround is handled on the Go side
                listener.updateDefaultInterface(interfaceName, interfaceIndex, false, false)
                return // successfully notified, don't retry
            }
        } else {
            listener.updateDefaultInterface(NO_INTERFACE_NAME, NO_INTERFACE_INDEX, false, false)
        }
    }

}
