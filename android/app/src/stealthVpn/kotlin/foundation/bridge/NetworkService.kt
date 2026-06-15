package foundation.bridge

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.VpnService
import android.net.wifi.WifiManager
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.Process
import android.system.OsConstants
import android.util.Log
import foundation.engine.libbox.InterfaceUpdateListener
import foundation.engine.libbox.Libbox
import foundation.engine.libbox.LocalDNSTransport
import foundation.engine.libbox.NetworkInterfaceIterator
import foundation.engine.libbox.Notification
import foundation.engine.libbox.StringIterator
import foundation.engine.libbox.TunOptions
import foundation.engine.libbox.WIFIState
import foundation.engine.mobile.Mobile
import foundation.engine.utils.FlutterEvent
import foundation.engine.utils.FlutterEventEmitter
import foundation.engine.utils.Opts
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.net.Inet6Address
import java.net.InetSocketAddress
import java.net.InterfaceAddress
import java.net.NetworkInterface

class NetworkService : VpnService(), foundation.engine.utils.PlatformInterface {
    companion object {
        private const val TAG = "NetworkService"
        const val ACTION_CONNECT = "foundation.bridge.CONNECT"
        const val ACTION_DISCONNECT = "foundation.bridge.DISCONNECT"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var tunFd: ParcelFileDescriptor? = null
    private val eventEmitter = object : FlutterEventEmitter {
        override fun sendEvent(event: FlutterEvent?) {
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_DISCONNECT -> {
                launchServiceWork { stopConnection() }
                START_NOT_STICKY
            }
            else -> {
                BridgeNotification.show(this, "Connecting")
                launchServiceWork { startConnection() }
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        runBlocking(Dispatchers.IO) {
            runCatching { Mobile.stopVPN() }
            closeTun()
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    private fun launchServiceWork(block: suspend () -> Unit) {
        serviceScope.launch {
            try {
                block()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (exception: Exception) {
                Log.e(TAG, "Failed service operation", exception)
                failConnection(exception)
            }
        }
    }

    private suspend fun failConnection(cause: Throwable? = null) = withContext(Dispatchers.IO) {
        runCatching { Mobile.stopVPN() }
        closeTun()
        if (cause != null) {
            BridgeState.setError(cause.message ?: "VPN operation failed")
        } else {
            BridgeState.set("disconnected")
        }
        BridgeNotification.clear(this@NetworkService)
        stopSelf()
    }

    private suspend fun startConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("connecting")
        if (!Mobile.isRadianceConnected()) {
            Mobile.startIPCServer(this@NetworkService, opts())
            Mobile.setupRadiance(opts(), eventEmitter)
        }
        Mobile.startVPN()
        BridgeState.set("connected")
        BridgeNotification.show(this@NetworkService, "Connected")
    }

    private suspend fun stopConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("disconnecting")
        runCatching { Mobile.stopVPN() }
        closeTun()
        BridgeState.set("disconnected")
        BridgeNotification.clear(this@NetworkService)
        stopSelf()
    }

    override fun openTun(tunOptions: TunOptions): Int {
        val fd = Builder()
            .setSession(BuildConfig.SESSION_NAME)
            .setMtu(tunOptions.mtu)
            .apply {
                val inet4Address = tunOptions.inet4Address
                while (inet4Address.hasNext()) {
                    val address = inet4Address.next()
                    addAddress(address.address(), address.prefix())
                }
                val inet6Address = tunOptions.inet6Address
                while (inet6Address.hasNext()) {
                    val address = inet6Address.next()
                    addAddress(address.address(), address.prefix())
                }
                if (tunOptions.autoRoute) {
                    addDnsServer(tunOptions.dnsServerAddress.value)
                    addRoute("0.0.0.0", 0)
                    addRoute("::", 0)
                }
                addDisallowedApplication(BuildConfig.APPLICATION_ID)
            }
            .establish()
            ?: error("connection permission is not prepared")
        tunFd = fd
        return fd.fd
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun postServiceClose() {
        closeTun()
    }

    override fun restartService() {
        runBlocking(Dispatchers.IO) {
            stopConnection()
            startConnection()
        }
    }

    override fun sendNotification(notification: Notification?) {
    }

    override fun systemCertificates(): StringIterator {
        return object : StringIterator {
            override fun hasNext(): Boolean = false
            override fun len(): Int = 0
            override fun next(): String = ""
        }
    }

    override fun writeLog(message: String?) {
    }

    override fun clearDNSCache() {
    }

    override fun underNetworkExtension(): Boolean {
        return false
    }

    override fun includeAllNetworks(): Boolean {
        return false
    }

    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return true
    }

    override fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }

    // Intentionally returns null for DNS-leak prevention. The main app's LocalResolver
    // uses Android's DnsResolver bound to the *physical* network — returning it here
    // would bypass the tunnel for DNS, creating a DNS-leak vector. Returning null
    // forces all DNS through the tunnel / sing-box DNS stack, which is the correct
    // behaviour for a stealth VPN. Bootstrap is safe: radiance connects via its own
    // dialing stack before startVPN() is called, so there is no resolve-before-tunnel
    // deadlock. Do NOT wire in a local resolver here without a full DNS-leak audit.
    override fun localDNSTransport(): LocalDNSTransport? {
        return null
    }

    // No-op by design (v1 limitation). Without a DefaultNetworkMonitor, sing-box does
    // not receive interface-change callbacks when the physical network switches
    // (e.g. Wi-Fi → cellular). As a result, existing connections stall after a
    // network switch and require a manual VPN restart to reconnect. This is a known
    // UX limitation tracked in the stealth-vpn follow-on issue.
    //
    // This is NOT a traffic or DNS leak: the tun is a full default route
    // (addRoute 0.0.0.0/0 + ::/0, no allowBypass), so stalled traffic cannot
    // spill onto the new physical interface — it simply stops until the tunnel
    // is restarted.
    override fun startDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
    }

    override fun closeDefaultInterfaceMonitor(listener: InterfaceUpdateListener) {
    }

    override fun readWIFIState(): WIFIState? {
        @Suppress("DEPRECATION")
        val wifiInfo = (getSystemService(Context.WIFI_SERVICE) as? WifiManager)
            ?.connectionInfo ?: return null
        var ssid = wifiInfo.ssid ?: return WIFIState("", "")
        if (ssid == "<unknown ssid>") return WIFIState("", "")
        if (ssid.startsWith("\"") && ssid.endsWith("\"")) {
            ssid = ssid.substring(1, ssid.length - 1)
        }
        return WIFIState(ssid, wifiInfo.bssid ?: "")
    }

    override fun packageNameByUid(uid: Int): String {
        val packages = packageManager.getPackagesForUid(uid)
        if (packages.isNullOrEmpty()) error("android: package not found")
        return packages[0]
    }

    @Suppress("DEPRECATION")
    override fun uidByPackageName(packageName: String): Int {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageUid(packageName, PackageManager.PackageInfoFlags.of(0))
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                packageManager.getPackageUid(packageName, 0)
            } else {
                packageManager.getApplicationInfo(packageName, 0).uid
            }
        } catch (e: PackageManager.NameNotFoundException) {
            error("android: package not found")
        }
    }

    override fun findConnectionOwner(
        ipProtocol: Int,
        sourceAddress: String,
        sourcePort: Int,
        destinationAddress: String,
        destinationPort: Int
    ): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) error("android: requires API 29")
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val uid = cm.getConnectionOwnerUid(
            ipProtocol,
            InetSocketAddress(sourceAddress, sourcePort),
            InetSocketAddress(destinationAddress, destinationPort)
        )
        if (uid == Process.INVALID_UID) error("android: connection owner not found")
        return uid
    }

    override fun getInterfaces(): NetworkInterfaceIterator {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val networks = cm.allNetworks
        val networkInterfaces = NetworkInterface.getNetworkInterfaces()?.toList() ?: emptyList()
        val interfaces = mutableListOf<foundation.engine.libbox.NetworkInterface>()
        for (network in networks) {
            val linkProperties = cm.getLinkProperties(network) ?: continue
            val networkCapabilities = cm.getNetworkCapabilities(network) ?: continue
            val interfaceName = linkProperties.interfaceName ?: continue
            val networkInterface = networkInterfaces.find { it.name == interfaceName } ?: continue
            try {
                val boxInterface = foundation.engine.libbox.NetworkInterface()
                boxInterface.name = interfaceName
                boxInterface.dnsServer = StringArray(
                    linkProperties.dnsServers.mapNotNull { it.hostAddress }.iterator()
                )
                boxInterface.type = when {
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
                        Libbox.InterfaceTypeWIFI
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
                        Libbox.InterfaceTypeCellular
                    networkCapabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
                        Libbox.InterfaceTypeEthernet
                    else -> Libbox.InterfaceTypeOther
                }
                boxInterface.index = networkInterface.index
                boxInterface.mtu = networkInterface.mtu
                boxInterface.addresses = StringArray(
                    networkInterface.interfaceAddresses
                        .mapTo(mutableListOf()) { it.toPrefix() }
                        .iterator()
                )
                var dumpFlags = 0
                if (networkCapabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
                    dumpFlags = OsConstants.IFF_UP or OsConstants.IFF_RUNNING
                }
                if (networkInterface.isLoopback) dumpFlags = dumpFlags or OsConstants.IFF_LOOPBACK
                if (networkInterface.isPointToPoint) dumpFlags = dumpFlags or OsConstants.IFF_POINTOPOINT
                if (networkInterface.supportsMulticast()) dumpFlags = dumpFlags or OsConstants.IFF_MULTICAST
                boxInterface.flags = dumpFlags
                boxInterface.metered = !networkCapabilities.hasCapability(
                    NetworkCapabilities.NET_CAPABILITY_NOT_METERED
                )
                interfaces.add(boxInterface)
            } catch (e: Exception) {
                Log.w(TAG, "Skipping interface $interfaceName: ${e.message}")
            }
        }
        return InterfaceArray(interfaces.iterator())
    }

    private class InterfaceArray(
        private val iterator: Iterator<foundation.engine.libbox.NetworkInterface>
    ) : NetworkInterfaceIterator {
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): foundation.engine.libbox.NetworkInterface = iterator.next()
    }

    private class StringArray(private val iterator: Iterator<String>) : StringIterator {
        override fun len(): Int = 0
        override fun hasNext(): Boolean = iterator.hasNext()
        override fun next(): String = iterator.next()
    }

    private fun InterfaceAddress.toPrefix(): String {
        return if (address is Inet6Address) {
            "${Inet6Address.getByAddress(address.address).hostAddress}/$networkPrefixLength"
        } else {
            "${address.hostAddress}/$networkPrefixLength"
        }
    }

    private fun opts(): Opts {
        return Opts().apply {
            dataDir = BridgePaths.dataDir(this@NetworkService)
            logDir = BridgePaths.logDir(this@NetworkService)
            logLevel = "warn"
            deviceid = BridgePaths.deviceId(this@NetworkService)
            locale = BridgePaths.locale()
            telemetryConsent = false
            env = ""
            platform = this@NetworkService
        }
    }

    @Synchronized
    private fun closeTun() {
        try {
            tunFd?.close()
        } finally {
            tunFd = null
        }
    }
}
