package org.getlantern.lantern.service

import android.annotation.SuppressLint
import android.net.LinkAddress
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Process
import android.system.Os
import android.system.OsConstants
import androidx.annotation.RequiresApi
import lantern.io.libbox.ConnectionOwner
import lantern.io.libbox.InterfaceUpdateListener
import lantern.io.libbox.Libbox
import lantern.io.libbox.LocalDNSTransport
import lantern.io.libbox.NetworkInterfaceIterator
import lantern.io.libbox.StringIterator
import lantern.io.libbox.WIFIState
import lantern.io.utils.PlatformInterface
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.LocalResolver
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface

interface PlatformInterfaceWrapper : PlatformInterface {

    override fun localDNSTransport(): LocalDNSTransport? {
        return LocalResolver
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return true
    }

    override fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }

    @RequiresApi(Build.VERSION_CODES.Q)
    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): ConnectionOwner {
        try {
            val uid = LanternApp.connectivity.getConnectionOwnerUid(
                ipProtocol,
                InetSocketAddress(sourceAddress, sourcePort),
                InetSocketAddress(destinationAddress, destinationPort)
            )
            if (uid == Process.INVALID_UID) error("android: connection owner not found")
            val packages = LanternApp.packageManager.getPackagesForUid(uid)
            val owner = ConnectionOwner()
            owner.userId = uid
            owner.userName = packages?.firstOrNull() ?: ""
            owner.setAndroidPackageNames(
                StringArray(packages?.toList()?.iterator() ?: emptyList<String>().iterator())
            )
            return owner
        } catch (e: Exception) {
            AppLogger.e("PlatformInterface", "getConnectionOwnerUid", e)
            e.printStackTrace(System.err)
            throw e
        }
    }

    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(listener)
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
        DefaultNetworkMonitor.setListener(null)
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val networks = LanternApp.connectivity.allNetworks
        // Best-effort: getNetworkInterfaces() returns null when no interfaces are
        // found and can throw (SocketException/SecurityException) on restricted
        // devices. Fall back to an empty list so the ConnectivityManager +
        // Os.if_nametoindex path below still runs instead of crashing here.
        val networkInterfaces = try {
            NetworkInterface.getNetworkInterfaces()?.toList() ?: emptyList()
        } catch (e: Exception) {
            AppLogger.e("PlatformInterface", "getNetworkInterfaces() failed; using ConnectivityManager only", e)
            emptyList()
        }
        val interfaces = mutableListOf<lantern.io.libbox.NetworkInterface>()
        for (network in networks) {
            val linkProperties = LanternApp.connectivity.getLinkProperties(network) ?: continue
            val networkCapabilities =
                LanternApp.connectivity.getNetworkCapabilities(network) ?: continue
            val interfaceName = linkProperties.interfaceName ?: continue
            // On some devices (notably Android 11 / API 30 and certain OEM ROMs)
            // NetworkInterface.getNetworkInterfaces() returns empty, so the name
            // match misses and we'd drop every network — leaving sing-box with
            // "no available network interface" (FD #176099). When that happens,
            // build the entry from ConnectivityManager + Os.if_nametoindex, which
            // don't depend on the restricted interface-enumeration syscall.
            val networkInterface = networkInterfaces.find { it.name == interfaceName }
            // Wrap all property access in a single try-catch so that if the
            // interface disappears mid-enumeration (e.g. tun0 during VPN restart)
            // we skip it instead of reporting a broken interface to sing-box.
            try {
                val boxInterface = lantern.io.libbox.NetworkInterface()
                boxInterface.name = interfaceName
                boxInterface.dnsServer =
                    StringArray(linkProperties.dnsServers.mapNotNull { it.hostAddress }.iterator())
                boxInterface.type = when {
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> Libbox.InterfaceTypeWIFI
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> Libbox.InterfaceTypeCellular
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                boxInterface.index = networkInterface?.index ?: Os.if_nametoindex(interfaceName)
                boxInterface.mtu = networkInterface?.mtu
                    ?: linkProperties.mtu.takeIf { it > 0 } ?: 1500
                boxInterface.addresses = StringArray(
                    (networkInterface?.interfaceAddresses?.map { it.toPrefix() }
                        ?: linkProperties.linkAddresses.map { it.toPrefix() }).iterator()
                )
                var dumpFlags = 0
                if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    dumpFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (networkInterface != null) {
                    if (networkInterface.isLoopback) {
                        dumpFlags = dumpFlags or OsConstants.IFF_LOOPBACK
                    }
                    if (networkInterface.isPointToPoint) {
                        dumpFlags = dumpFlags or OsConstants.IFF_POINTOPOINT
                    }
                    if (networkInterface.supportsMulticast()) {
                        dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
                    }
                } else {
                    // No java.net.NetworkInterface to query loopback/p2p/multicast;
                    // ConnectivityManager only reports real underlying networks (never
                    // loopback), so assume a normal multicast-capable physical link.
                    dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
                }
                boxInterface.flags = dumpFlags
                boxInterface.metered =
                    !networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
                interfaces.add(boxInterface)
            } catch (e: Exception) {
                AppLogger.e(
                    "PlatformInterface",
                    "Skipping interface $interfaceName: device may no longer exist",
                    e
                )
            }
        }
        return InterfaceArray(interfaces.iterator())
    }

    override fun underNetworkExtension(): Boolean {
        return false
    }

    override fun includeAllNetworks(): Boolean {
        return false
    }

    override fun clearDNSCache() {
    }

    override fun readWIFIState(): WIFIState? {
        @Suppress("DEPRECATION") val wifiInfo =
            LanternApp.wifiManager.connectionInfo ?: return null
        var ssid = wifiInfo.ssid
        if (ssid == "<unknown ssid>") {
            return WIFIState("", "")
        }
        if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
            ssid = ssid.substring(1, ssid.length - 1)
        }
        return WIFIState(ssid, wifiInfo.bssid)
    }

    private class InterfaceArray(private val iterator: Iterator<lantern.io.libbox.NetworkInterface>) :
        NetworkInterfaceIterator {

        override fun hasNext(): Boolean {
            return iterator.hasNext()
        }

        override fun next(): lantern.io.libbox.NetworkInterface {
            return iterator.next()
        }

    }

    private class StringArray(private val iterator: Iterator<String>) : StringIterator {

        override fun len(): Int {
            // not used by core
            return 0
        }

        override fun hasNext(): Boolean {
            return iterator.hasNext()
        }

        override fun next(): String {
            return iterator.next()
        }
    }

    private fun InterfaceAddress.toPrefix(): String {
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/${networkPrefixLength}"
        } else {
            "${address.hostAddress}/${networkPrefixLength}"
        }
    }

    // ConnectivityManager fallback when java.net.NetworkInterface is unavailable.
    private fun LinkAddress.toPrefix(): String {
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/${prefixLength}"
        } else {
            "${address.hostAddress}/${prefixLength}"
        }
    }

    private val NetworkInterface.flags: Int
        @SuppressLint("SoonBlockedPrivateApi") get() {
            val getFlagsMethod = NetworkInterface::class.java.getDeclaredMethod("getFlags")
            return getFlagsMethod.invoke(this) as Int
        }
}