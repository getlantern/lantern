package org.getlantern.lantern.service

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import lantern.io.libbox.Notification
import lantern.io.libbox.TunOptions
import lantern.io.mobile.Mobile
import lantern.io.utils.Opts
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.notification.NotificationHelper
import org.getlantern.lantern.utils.DeviceUtil
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.logDir
import org.getlantern.lantern.utils.toIpPrefix
import org.getlantern.lantern.BuildConfig

/**
 * Service to manage VPN connection and Radiance setup, and other VPN-related tasks.
 * Since this service is used for the quick tile,
 * it should not include any logic that needs to be connected with any activity.
 * everything should be done in independent
 */
class LanternVpnService : VpnService(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "VpnService"
        private const val sessionName = "LanternVpn"
        const val ACTION_START_RADIANCE = "com.getlantern.START_RADIANCE"
        const val ACTION_START_VPN = "org.getlantern.START_VPN"
        const val ACTION_CONNECT_TO_SERVER = "org.getlantern.CONNECT_TO_SERVER"
        const val ACTION_STOP_VPN = "org.getlantern.START_STOP"
        const val ACTION_TILE_START = "org.getlantern.TILE_START"
        lateinit var instance: LanternVpnService
    }

    private val notificationHelper = NotificationHelper()

    private var mInterface: ParcelFileDescriptor? = null

    // Create a CoroutineScope tied to the service's lifecycle.
    // SupervisorJob ensures that failure in one child doesn't cancel the whole scope.
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        instance = this
        val action = intent?.action ?: return START_NOT_STICKY
        if (!MainActivity.receiverRegistered) {
            VpnStatusManager.registerVPNStatusReceiver(this)
            MainActivity.receiverRegistered = true
        }

        return when (action) {
            ACTION_START_RADIANCE -> {
                serviceScope.launch {
                    startRadiance()
                }
                START_NOT_STICKY
            }

            ACTION_START_VPN -> {
                serviceScope.launch {
                    startVPN()
                }
                START_STICKY
            }
            ACTION_CONNECT_TO_SERVER -> {
                serviceScope.launch {
                    connectToServer(
                        intent.getStringExtra("location") ?: "",
                        intent.getStringExtra("tag") ?: ""
                    )
                }
                START_STICKY
            }

            ACTION_TILE_START -> {
                serviceScope.launch {
                    if (!Mobile.isRadianceConnected()) {
                        startRadiance()
                    }
                    startVPN()
                    notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
                }
                START_STICKY // Return START_STICKY for ACTION_TILE_START
            }

            ACTION_STOP_VPN -> {
                serviceScope.launch {
                    doStopVPN()
                }
                START_NOT_STICKY
            }

            else -> START_STICKY
        }
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

    override fun sendNotification(notification: Notification?) {
        notificationHelper.sendNotification(notification)
    }

    override fun writeLog(p0: String?) {
        Log.d(TAG, "writeLog: $p0")
    }

    private suspend fun startRadiance() {
        try {
            withContext(Dispatchers.IO) {
                Mobile.setupRadiance(opts())
            }
            Log.d(TAG, "Radiance setup completed ${DeviceUtil.deviceId()}")
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
            Mobile.startVPN(this@LanternVpnService, opts())
            Log.d(TAG, "VPN service started")
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                QuickTileService.triggerUpdateTileState(this@LanternVpnService, true)
            }
        }.onFailure { e ->
            Log.e(TAG, "Error starting VPN service", e)
            VpnStatusManager.postVPNError(
                errorCode = "start_vpn",
                errorMessage = "Error starting VPN service",
                error = e,
            )
        }
    }

    suspend fun connectToServer(location:String,tag:String) = withContext(Dispatchers.IO) {
        if (prepare(this@LanternVpnService) != null) {
            VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            return@withContext
        }
        runCatching {
            DefaultNetworkMonitor.start()
            Mobile.connectToServer(location,tag,this@LanternVpnService, opts())
            Log.d(TAG, "Connected to server")
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                QuickTileService.triggerUpdateTileState(this@LanternVpnService, true)
            }
        }.onFailure { e ->
            Log.e(TAG, "error while connectToServer ", e)
            VpnStatusManager.postVPNError(
                errorCode = "connect_to_server",
                errorMessage = "Error connecting to server",
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

                DefaultNetworkMonitor.stop()
                VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                notificationHelper.stopVPNConnectedNotification(this@LanternVpnService)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    QuickTileService.triggerUpdateTileState(this@LanternVpnService, false)
                }

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

        // Disallow traffic from our own app to the VPN.
        builder.addDisallowedApplication(BuildConfig.APPLICATION_ID)

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

    fun opts(): Opts {
        val opts = Opts()
        opts.dataDir = initConfigDir()
        opts.logDir = logDir()
        opts.logLevel = "trace"
        opts.deviceid = DeviceUtil.deviceId()
        opts.locale = DeviceUtil.getLanguageCode(this@LanternVpnService)
        return opts
    }

}
