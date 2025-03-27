package org.getlantern.lantern.service

import android.content.ComponentName
import android.content.Intent
import android.content.ServiceConnection
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import lantern.io.libbox.Libbox
import lantern.io.libbox.Notification
import lantern.io.libbox.TunOptions
import lantern.io.mobile.Mobile
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.LocalResolver
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.toIpPrefix


class LanternVpnService : VpnService(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "VpnService"
        private const val sessionName = "LanternVpn"
        const val ACTION_START_RADIANCE = "com.getlantern.START_RADIANCE"
        const val ACTION_START_VPN = "org.getlantern.START_VPN"
        const val ACTION_STOP_VPN = "org.getlantern.START_STOP"
    }

    private var mInterface: ParcelFileDescriptor? = null


    // Create a CoroutineScope tied to the service's lifecycle.
    // SupervisorJob ensures that failure in one child doesn't cancel the whole scope.
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val lanternServiceConnection: ServiceConnection = object : ServiceConnection {
        override fun onServiceDisconnected(name: ComponentName) {
            Log.e(TAG, "LanternService disconnected, disconnecting VPN")
//            stop()
        }

        override fun onServiceConnected(name: ComponentName, service: IBinder) {}
    }


    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val i = intent?.action ?: return START_STICKY
        if (!MainActivity.receiverRegistered) {
            VpnStatusManager.registerVPNStatusReceiver(this)
            MainActivity.receiverRegistered = true
        }

        i.let { action ->
            when (action) {
                ACTION_START_RADIANCE -> {
                    serviceScope.launch {
                        startRadiance()
                    }
                }

                ACTION_START_VPN -> {
                    serviceScope.launch {
                        startVPN()
                        MainActivity.instance.notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
                    }

                }

                ACTION_STOP_VPN -> {
                    serviceScope.launch {
                        doStopVPN()
                    }
                }

                else -> {}
            }
        }
        return START_STICKY
    }


    override fun onRevoke() {
        super.onRevoke()
        destroy()
    }

    override fun onDestroy() {
        super.onDestroy()
        destroy()
    }

    override fun autoDetectInterfaceControl(p0: Int) {
        protect(p0)
    }

    override fun openTun(tunOptions: TunOptions): Int {
        val vpnBuilder = createVPNBuilder(tunOptions)
        val pfd = vpnBuilder.establish()
            ?: error("android: the application is not prepared or is revoked")
        mInterface = pfd
        return pfd.fd
    }

    override fun sendNotification(p0: Notification?) {
        TODO("Not yet implemented")
    }

    override fun writeLog(p0: String?) {
        Log.d(TAG, "writeLog: $p0")
    }

    private suspend fun startRadiance() {
        try {
            withContext(Dispatchers.IO) {
                Mobile.setupRadiance(initConfigDir(), this@LanternVpnService)
            }
            Log.d(TAG, "Radiance setup completed")
        } catch (e: Exception) {
            Log.e(TAG, "Error in Radiance setup", e)
        }
    }


    private suspend fun startVPN() = withContext(Dispatchers.IO) {
        if (prepare(this@LanternVpnService) != null) {
            VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            return@withContext
        }
        runCatching {
            DefaultNetworkMonitor.start()
            Libbox.registerLocalDNSTransport(LocalResolver)
            Libbox.setMemoryLimit(false)
            Mobile.startVPN()
            Log.d(TAG, "VPN service started")
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
        }.onFailure { e ->
            Log.e(TAG, "Error starting VPN service", e)
            VpnStatusManager.postVPNError(
                errorCode = "start_vpn",
                errorMessage = "Error starting VPN service",
                error = e,
            )
        }
    }


    fun doStopVPN() {
        Log.d("LanternVpnService", "doStopVPN")
        try {
            VpnStatusManager.postVPNStatus(VPNStatus.Disconnecting)
            serviceScope.launch {
                mInterface?.close();
                mInterface = null
                if (Mobile.isVPNConnected()) {
                    Mobile.stopVPN()
                }
                Libbox.registerLocalDNSTransport(null)
                DefaultNetworkMonitor.stop()
                VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                MainActivity.instance.notificationHelper.stopVPNConnectedNotification(this@LanternVpnService)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN service", e)
            VpnStatusManager.postVPNError(
                error = e, errorCode = "stop_vpn", errorMessage = "Error stopping VPN service"
            )
        }
    }

    private fun destroy() {
        doStopVPN()
        VpnStatusManager.unregisterVPNStatusReceiver(this)
        stopSelf()
    }

    private fun createVPNBuilder(options: TunOptions): VpnService.Builder {
        val builder = Builder().setSession(sessionName).setMtu(options.mtu)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }

        val inet4Address = options.inet4Address
        while (inet4Address.hasNext()) {
            val address = inet4Address.next()
            builder.addAddress(address.address(), address.prefix())
        }

        val inet6Address = options.inet6Address
        while (inet6Address.hasNext()) {
            val address = inet6Address.next()
            builder.addAddress(address.address(), address.prefix())
        }

        if (options.autoRoute) {
            builder.addDnsServer(options.dnsServerAddress.value)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val inet4RouteAddress = options.inet4RouteAddress
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        builder.addRoute(inet4RouteAddress.next().toIpPrefix())
                    }
                } else if (options.inet4Address.hasNext()) {
                    builder.addRoute("0.0.0.0", 0)
                }

                val inet6RouteAddress = options.inet6RouteAddress
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        builder.addRoute(inet6RouteAddress.next().toIpPrefix())
                    }
                } else if (options.inet6Address.hasNext()) {
                    builder.addRoute("::", 0)
                }

                val inet4RouteExcludeAddress = options.inet4RouteExcludeAddress
                while (inet4RouteExcludeAddress.hasNext()) {
                    builder.excludeRoute(inet4RouteExcludeAddress.next().toIpPrefix())
                }

                val inet6RouteExcludeAddress = options.inet6RouteExcludeAddress
                while (inet6RouteExcludeAddress.hasNext()) {
                    builder.excludeRoute(inet6RouteExcludeAddress.next().toIpPrefix())
                }
            } else {
                val inet4RouteAddress = options.inet4RouteRange
                if (inet4RouteAddress.hasNext()) {
                    while (inet4RouteAddress.hasNext()) {
                        val address = inet4RouteAddress.next()
                        builder.addRoute(address.address(), address.prefix())
                    }
                }

                val inet6RouteAddress = options.inet6RouteRange
                if (inet6RouteAddress.hasNext()) {
                    while (inet6RouteAddress.hasNext()) {
                        val address = inet6RouteAddress.next()
                        builder.addRoute(address.address(), address.prefix())
                    }
                }
            }
        }
        return builder
    }

}