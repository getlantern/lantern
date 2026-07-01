package org.getlantern.lantern.service

import android.net.Network
import android.os.Build
import android.system.Os

import lantern.io.libbox.InterfaceUpdateListener
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.utils.AppLogger
import java.net.NetworkInterface
import java.util.concurrent.Executors

object DefaultNetworkMonitor {
    private const val TAG = "DefaultNetworkMonitor"
    private const val NO_INTERFACE_NAME = ""
    private const val NO_INTERFACE_INDEX = -1
    private const val INTERFACE_RESOLUTION_RETRY_COUNT = 10
    private const val INTERFACE_RESOLUTION_RETRY_DELAY_MS = 100L

    private data class ResolvedInterface(
        val name: String,
        val index: Int,
    )

    var defaultNetwork: Network? = null

    // Written by setListener and read by checkDefaultInterfaceUpdate on possibly
    // different threads, so @Volatile guarantees the read sees the latest write.
    @Volatile
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

    // Default-network callbacks arrive on the main looper, so resolution runs on a
    // single background thread to keep the retry loop's sleeps and the JNI call off
    // the UI thread while still applying updates in network-change order. The monitor
    // is a process-wide singleton; the daemon worker intentionally lives for the
    // process lifetime, so there is no per-session shutdown.
    private val updateExecutor = Executors.newSingleThreadExecutor { r ->
        Thread(r, "default-interface-monitor").apply { isDaemon = true }
    }

    private fun checkDefaultInterfaceUpdate(newNetwork: Network?) {
        val listener = listener ?: return
        updateExecutor.execute {
            when (newNetwork) {
                null -> {
                    AppLogger.i(TAG, "Default network lost; clearing default interface")
                    notifyDefaultInterface(listener, NO_INTERFACE_NAME, NO_INTERFACE_INDEX)
                }
                else -> {
                    val resolved = resolveDefaultInterface(newNetwork)
                    if (resolved == null) {
                        AppLogger.w(
                            TAG,
                            "Failed to resolve default interface after $INTERFACE_RESOLUTION_RETRY_COUNT attempts",
                        )
                        return@execute
                    }
                    AppLogger.i(TAG, "Default interface resolved: ${resolved.name} (index ${resolved.index})")
                    notifyDefaultInterface(listener, resolved.name, resolved.index)
                }
            }
        }
    }

    private fun notifyDefaultInterface(listener: InterfaceUpdateListener, name: String, index: Int) {
        listener.updateDefaultInterface(name, index, false, false)
    }

    private fun resolveDefaultInterface(network: Network): ResolvedInterface? {
        repeat(INTERFACE_RESOLUTION_RETRY_COUNT) { attempt ->
            // getLinkProperties can briefly return null (or a null interfaceName)
            // right after a network change, so resolve inside the retry loop.
            val interfaceName = LanternApp.connectivity
                .getLinkProperties(network)
                ?.interfaceName

            if (interfaceName != null) {
                // getByName relies on the interface-enumeration syscall, which is
                // restricted on some Android versions/ROMs (returns null or throws
                // there); Os.if_nametoindex recovers the index so the default
                // interface is still delivered, otherwise every outbound fails to bind.
                val interfaceIndex = getInterfaceIndex(interfaceName)
                if (interfaceIndex > 0) {
                    return ResolvedInterface(interfaceName, interfaceIndex)
                }
            }

            val hasMoreAttempts = attempt < INTERFACE_RESOLUTION_RETRY_COUNT - 1
            if (hasMoreAttempts && !sleepBeforeRetry()) {
                return null
            }
        }

        return null
    }

    private fun getInterfaceIndex(interfaceName: String): Int =
        try {
            NetworkInterface.getByName(interfaceName)?.index
                ?: Os.if_nametoindex(interfaceName)
        } catch (e: Exception) {
            AppLogger.w(TAG, "getByName failed for $interfaceName; falling back to if_nametoindex", e)
            runCatching { Os.if_nametoindex(interfaceName) }.getOrDefault(0)
        }

    private fun sleepBeforeRetry(): Boolean =
        try {
            Thread.sleep(INTERFACE_RESOLUTION_RETRY_DELAY_MS)
            true
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
}
