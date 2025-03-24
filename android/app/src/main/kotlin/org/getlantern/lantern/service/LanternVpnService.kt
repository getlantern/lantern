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
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.toIpPrefix

class LanternVpnService : VpnService(), PlatformInterfaceWrapper {

    companion object {
        private const val TAG = "VpnService"
        private const val sessionName = "LanternVpn"
        private const val privateAddress = "10.0.0.2"
        private const val VPN_MTU = 1500
        const val ACTION_START_RADIANCE = "com.getlantern.START_RADIANCE"
        const val ACTION_START_VPN = "org.getlantern.START_VPN"
        const val ACTION_STOP_VPN = "org.getlantern.START_STOP"
    }

    // Create a CoroutineScope tied to the service's lifecycle.
    // SupervisorJob ensures that failure in one child doesn't cancel the whole scope.
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private var mInterface: ParcelFileDescriptor? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val i = intent?.action ?: return START_STICKY
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
                    }
                }

                ACTION_STOP_VPN -> {
                    serviceScope.launch {
                        stopVPN()
                    }
                }

                else -> {}
            }
        }
        return START_STICKY
    }


    override fun onRevoke() {
        super.onRevoke()

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
        TODO("Not yet implemented")
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
            VpnStatusManager.postStatus(error = Exception("Missing VPN permission"))
            return@withContext
        }
        runCatching {
            Mobile.startVPN()
            Log.d(TAG, "VPN service started")
            VpnStatusManager.postStatus(successMessage = "VPN service started")
        }.onFailure { e ->
//            Log.e(TAG, "Error starting VPN service", e)
            VpnStatusManager.postStatus(error = e)
        }
    }


    private fun stopVPN() {
        Mobile.stopVPN()
    }

    //todo this is just for testing
    // need to update it according to the actual implementation
    private fun createVPNBuilder(options: TunOptions): VpnService.Builder {
        val builder = Builder()
            .setSession(sessionName)
            .setMtu(options.mtu)

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