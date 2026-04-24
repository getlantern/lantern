package org.getlantern.lantern.service

import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import lantern.io.libbox.Notification
import lantern.io.libbox.StringIterator
import lantern.io.libbox.TunOptions
import lantern.io.mobile.Mobile
import lantern.io.utils.Opts
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.notification.NotificationHelper
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.DeviceUtil
import org.getlantern.lantern.utils.FlutterEventListener
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.getRadianceEnv
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.isTelemetryEnabled
import org.getlantern.lantern.utils.logDir
import org.getlantern.lantern.utils.toIpPrefix

/**
 * Service to manage VPN connection and Radiance setup, and other VPN-related tasks.
 * Since this service is used for the quick tile,
 * it should not include any logic that needs to be connected with any activity.
 * everything should be done in independent
 */
class LanternVpnService :
    VpnService(),
    PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "LanternVpnService"
        private const val sessionName = "LanternVpn"
        const val ACTION_START_RADIANCE = "com.getlantern.START_RADIANCE"
        const val ACTION_START_VPN = "org.getlantern.START_VPN"
        const val ACTION_CONNECT_TO_SERVER = "org.getlantern.CONNECT_TO_SERVER"
        const val ACTION_STOP_VPN = "org.getlantern.START_STOP"
        const val ACTION_TILE_START = "org.getlantern.TILE_START"

        // Hard ceiling on how long Mobile.startVPN / connectToServer can block.
        // Radiance + sing-box + TUN establish usually finishes in under 15 s;
        // anything above 60 s means the Go side has deadlocked (see Freshdesk
        // #173507, where /service/start hung and the UI appeared frozen until
        // a phone reboot). Without this timeout the coroutine could wait forever.
        private const val VPN_START_TIMEOUT_MS = 60_000L

        // Single-flight gate: when we time out the connect() call, we detach
        // the coroutine rather than waiting for the JNI call to honor
        // cancellation (it doesn't). The orphan keeps a Dispatchers.IO thread
        // pinned until Go eventually returns. To prevent multiple rapid
        // retries from accumulating orphans and pressuring the IO pool, reject
        // new connect attempts while a previous one is still in flight. The
        // flag clears when the orphan's coroutine actually completes.
        private val connectInFlight = AtomicBoolean(false)

        lateinit var instance: LanternVpnService
    }

    private val notificationHelper = NotificationHelper()

    private val flutterEventListener = FlutterEventListener()

    private var mInterface: ParcelFileDescriptor? = null

    /**
     * Safely close the TUN interface file descriptor.
     * Synchronized to prevent double-close from concurrent callers
     * (onDestroy, postServiceClose, doStopVPN can all race).
     */
    @Synchronized
    private fun closeTunInterface() {
        try {
            mInterface?.close()
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error closing TUN interface", e)
        } finally {
            mInterface = null
        }
    }

    // Create a CoroutineScope tied to the service's lifecycle.
    // SupervisorJob ensures that failure in one child doesn't cancel the whole scope.
    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int,
    ): Int {
        instance = this
        val action = intent?.action ?: return START_NOT_STICKY
        if (!MainActivity.receiverRegistered) {
            VpnStatusManager.registerVPNStatusReceiver()
            MainActivity.receiverRegistered = true
        }
        AppLogger.d(TAG, "Received action: $action")
        return when (action) {
            ACTION_START_RADIANCE -> {
                serviceScope.launch {
                    startRadiance()
                }
                AppLogger.d(TAG, "Started Radiance")
                START_NOT_STICKY
            }

            ACTION_START_VPN -> {
                serviceScope.launch {
                    startVPN()
                }
                AppLogger.d(TAG, "Started VPN")
                START_STICKY
            }

            ACTION_CONNECT_TO_SERVER -> {
                serviceScope.launch {
                    connectToServer(intent.getStringExtra("tag") ?: "")
                }
                AppLogger.d(TAG, "Connecting to server")
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
                AppLogger.d(TAG, "Tile triggered VPN start")
                START_STICKY
            }

            ACTION_STOP_VPN -> {
                AppLogger.d(TAG, "Received ACTION_STOP_VPN")
                serviceScope.launch {
                    performStopVPN()
                }
                START_NOT_STICKY
            }

            else -> START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        try {
            AppLogger.d(TAG, "destroying LanternVpnService")
            closeTunInterface()
            // Clean up synchronously — cannot use serviceScope here because
            // it is cancelled in the finally block below.
            //
            // Call Mobile.stopVPN() as long as radiance is up. The previous
            // isVPNConnected() guard (status == Connected) was wrong — if the
            // tunnel is in any non-Connected state (Restarting, Connecting,
            // Disconnecting, Error), c.tunnel is still non-nil on the Go side
            // and needs to be closed so the next process lifetime starts clean.
            // Mobile.stopVPN() itself is a no-op when c.tunnel is nil.
            val radianceConnected = Mobile.isRadianceConnected()
            AppLogger.d(TAG, "onDestroy — radianceConnected=$radianceConnected")
            if (!radianceConnected) {
                AppLogger.d(TAG, "Skipping stopVPN — Radiance IPC not running")
            } else {
                runCatching { Mobile.stopVPN() }
                    .onSuccess { AppLogger.d(TAG, "stopVPN completed during destroy") }
                    .onFailure { e ->
                        AppLogger.e(TAG, "Mobile.stopVPN() failed during destroy", e)
                    }
            }
            runCatching {
                runBlocking(Dispatchers.IO) { DefaultNetworkMonitor.stop() }
            }.onFailure { e ->
                AppLogger.e(
                    TAG,
                    "DefaultNetworkMonitor.stop() failed during destroy",
                    e
                )
            }
            notificationHelper.stopVPNConnectedNotification(this)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                QuickTileService.triggerUpdateTileState(this, false)
            }
            serviceCleanUp()

        } finally {
            serviceScope.cancel()
            super.onDestroy()
        }
    }

    override fun autoDetectInterfaceControl(p0: Int) {
        protect(p0)
    }

    override fun openTun(tunOptions: TunOptions): Int {
        val vpnBuilder = createVPNBuilder(tunOptions)
        val pfd =
            vpnBuilder.establish()
                ?: error("android: the application is not prepared or is revoked")
        mInterface = pfd
        return pfd.fd
    }

    override fun postServiceClose() {
        AppLogger.i(TAG, "postServiceClose called")
        closeTunInterface()
    }

    override fun restartService() {
        AppLogger.i(TAG, "restartService called")
        // Radiance's Restart() sets the tunnel status to Restarting, then
        // calls us synchronously and treats a successful return as "restart
        // complete." If we fire-and-forget via serviceScope.launch and return,
        // radiance thinks it succeeded but the tunnel is still in Restarting —
        // and if the Android service is torn down (onDestroy, process
        // pressure) before the launched coroutine completes, the tunnel
        // wedges in Restarting forever. Every subsequent Connect fails with
        // "tunnel is currently Restarting" (getlantern/engineering#3297
        // issues 1-3, Freshdesk #173681).
        //
        // Block until stopVPNTunnel + startVPN finish so the return actually
        // reflects the state radiance observes. c.mu is released on the Go
        // side before RestartService is invoked, so synchronous callbacks
        // into Mobile.* from this thread don't deadlock.
        runBlocking(Dispatchers.IO) {
            stopVPNTunnel()
            startVPN()
            // launchVPN (wrapping startVPN) catches failures via
            // runCatching { ... }.onFailure { ... } and returns normally,
            // so a nil return from startVPN doesn't mean the restart
            // succeeded. Verify the postcondition on the Go side and
            // throw if it's not met — the exception propagates through
            // runBlocking → restartService → radiance's Restart() as a
            // non-nil error, which is what tells the caller the restart
            // actually failed and the tunnel needs healing rather than
            // wedging forever in Restarting.
            if (!Mobile.isVPNConnected()) {
                val msg = "restartService failed: VPN not connected after stopVPNTunnel + startVPN"
                AppLogger.e(TAG, msg)
                throw IllegalStateException(msg)
            }
        }
        AppLogger.i(TAG, "restartService completed")
    }

    override fun sendNotification(notification: Notification?) {
        notificationHelper.sendNotification(notification)
    }

    override fun systemCertificates(): StringIterator {
        //return empty iterator as we are not using system certificates
        return object : StringIterator {
            override fun hasNext(): Boolean = false
            override fun len(): Int {
                return 0
            }

            override fun next(): String = ""
        }

    }

    override fun writeLog(p0: String?) {
        AppLogger.d(TAG, "writeLog: $p0")
    }

    private suspend fun startRadiance() {
        try {
            withContext(Dispatchers.IO) {
                Mobile.startIPCServer(this@LanternVpnService, opts())
                Mobile.setupRadiance(opts(), flutterEventListener)
            }
            AppLogger.d(TAG, "Radiance setup completed")
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error in Radiance setup", e)
        }
    }

     suspend fun startVPN() = launchVPN(
        errorCode = "start_vpn",
        cleanUpOnFailure = true,
    ) {
        Mobile.startVPN()
        AppLogger.d(TAG, "VPN service started")
    }

    suspend fun connectToServer(
        tag: String,
    ) = launchVPN(
        errorCode = "connect_to_server",
        cleanUpOnFailure = false,
    ) {
        Mobile.connectToServer( tag)
        AppLogger.d(TAG, "Connected to server")
    }

    /**
     * Common flow for starting/connecting VPN: checks permission, shows foreground
     * notification, starts network monitor, runs [connect], then updates UI on success.
     */
    private suspend fun launchVPN(
        errorCode: String,
        cleanUpOnFailure: Boolean,
        connect: suspend () -> Unit,
    ) = withContext(Dispatchers.IO) {
        if (prepare(this@LanternVpnService) != null) {
            VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            return@withContext
        }
        // Show foreground notification immediately — required by the OS as soon as
        // VPN service starts, replaced by connected notification on success.
        notificationHelper.showStartingVPNConnectedNotification(this@LanternVpnService)
        runCatching {
            // Radiance is pre-warmed via ACTION_START_RADIANCE, but as a background
            // service it may have been killed by the OS before setup completed.
            // Re-run setup here under the foreground notification so it is guaranteed
            // to finish before we attempt to start the VPN tunnel.
            if (!Mobile.isRadianceConnected()) {
                AppLogger.d(TAG, "Radiance not ready, setting up before VPN start")
                Mobile.startIPCServer(this@LanternVpnService, opts())
                Mobile.setupRadiance(opts(), flutterEventListener)
            }
            DefaultNetworkMonitor.setNetworkChangeCallback { updateUnderlyingNetworks() }
            DefaultNetworkMonitor.start()
            // Tell Android which physical network underlies our VPN so that
            // ConnectivityManager.getAllNetworks() returns it alongside the VPN.
            // Without this, some Android 10+ devices report only the VPN network,
            // causing sing-box to see no physical interface and blocking all traffic.
            updateUnderlyingNetworks()
            // Bound the Mobile.startVPN / connectToServer call with a wall-clock
            // timeout. These are blocking JNI calls with no suspension points,
            // so withTimeout around a direct invocation wouldn't fire — we run
            // the call in async() and await it so withTimeout has a real
            // cancellation point.
            //
            // Run it in a DETACHED CoroutineScope (not a structured
            // coroutineScope { } / the enclosing withContext), because on
            // timeout structured concurrency would cancel the deferred and
            // then wait for it to complete — and since the JNI call doesn't
            // honor cooperative cancellation, that wait is exactly the hang
            // we're trying to prevent. A detached SupervisorJob scope lets
            // us stop awaiting without joining; the orphan coroutine keeps
            // running until Go returns (or the process exits), but the
            // caller is unblocked and the UI surfaces a clear error instead
            // of a frozen button only a phone reboot can clear
            // (Freshdesk #173507).
            //
            // Reject concurrent attempts with connectInFlight so repeated
            // retries while a previous call is stuck in JNI don't accumulate
            // orphan coroutines on Dispatchers.IO. Clear the flag from the
            // Deferred completion path so early cancellation before the async
            // body starts can't wedge future attempts.
            if (!connectInFlight.compareAndSet(false, true)) {
                throw IllegalStateException("previous VPN connect attempt still in flight")
            }
            val connectScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
            val deferred = connectScope.async { connect() }
            deferred.invokeOnCompletion {
                connectInFlight.set(false)
            }
            try {
                withTimeout(VPN_START_TIMEOUT_MS) { deferred.await() }
            } catch (e: TimeoutCancellationException) {
                deferred.cancel()
                throw e
            } finally {
                connectScope.cancel()
            }
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                QuickTileService.triggerUpdateTileState(this@LanternVpnService, true)
            }
        }.onFailure { e ->
            val timedOut = e is TimeoutCancellationException
            if (timedOut) {
                AppLogger.e(TAG, "VPN operation ($errorCode) timed out after ${VPN_START_TIMEOUT_MS}ms — Go side likely deadlocked", e)
            } else {
                AppLogger.e(TAG, "Error in VPN operation ($errorCode)", e)
            }
            // Clear the network change callback to avoid leaking this service
            // instance through the static DefaultNetworkMonitor singleton.
            DefaultNetworkMonitor.setNetworkChangeCallback(null)
            runCatching { runBlocking { DefaultNetworkMonitor.stop() } }
                .onFailure { stopErr -> AppLogger.e(TAG, "DefaultNetworkMonitor.stop() failed in error path", stopErr) }
            VpnStatusManager.postVPNError(
                errorCode = if (timedOut) "${errorCode}_timeout" else errorCode,
                errorMessage = if (timedOut) "VPN operation timed out" else "Error in VPN operation",
                error = e,
            )
            if (cleanUpOnFailure) serviceCleanUp()
        }
    }

    fun doStopVPN() {
        AppLogger.d(TAG, "doStopVPN")
        serviceScope.launch {
            performStopVPN()
        }
    }

    /**
     * Tears down only the VPN tunnel without touching the broadcast receiver
     * or service lifecycle. Used by [restartService] so the receiver stays
     * registered and the service can still receive stop commands after restart.
     */
    private suspend fun stopVPNTunnel() {
        try {
            closeTunInterface()
            // Unconditionally call Mobile.stopVPN() as long as radiance is up.
            // The old isVPNConnected() guard looked at status == Connected,
            // which is wrong during a restart: radiance sets the tunnel to
            // Restarting before calling back into the platform, so the check
            // would skip stopVPN and leave the tunnel wedged in Restarting
            // (getlantern/engineering#3297). Mobile.stopVPN() itself is a
            // no-op when c.tunnel is nil, so the guard is unnecessary.
            runCatching {
                if (!Mobile.isRadianceConnected()) {
                    AppLogger.d(TAG, "Radiance IPC not running, skipping stopVPN")
                    return@runCatching
                }
                Mobile.stopVPN()
            }
                .onFailure { e -> AppLogger.e(TAG, "Mobile.stopVPN() failed", e) }

            runCatching { DefaultNetworkMonitor.stop() }
                .onFailure { e -> AppLogger.e(TAG, "DefaultNetworkMonitor.stop() failed", e) }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error tearing down VPN tunnel", e)
        }
    }

    /**
     * Full VPN stop: tears down the tunnel, updates UI/notifications/tile,
     * posts disconnected status, and cleans up the service (unregisters receiver).
     * Used by [doStopVPN] and [ACTION_STOP_VPN].
     */
    private suspend fun performStopVPN() {
        VpnStatusManager.postVPNStatus(VPNStatus.Disconnecting)
        try {
            stopVPNTunnel()
            notificationHelper.stopVPNConnectedNotification(this@LanternVpnService)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                QuickTileService.triggerUpdateTileState(this@LanternVpnService, false)
            }
            VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
            serviceCleanUp()
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error stopping VPN service", e)
            VpnStatusManager.postVPNError(
                error = e,
                errorCode = "stop_vpn",
                errorMessage = "Error stopping VPN service",
            )
        }
    }

    /**
     * Informs the OS which physical networks underlie our VPN. This ensures
     * ConnectivityManager.getAllNetworks() returns the physical network alongside
     * the VPN, which sing-box needs to bind outbound connections to the real
     * interface. Without this, some devices (notably Android 10) only see the VPN
     * network and sing-box's direct outbound fails with "no available network interface".
     */
    private fun updateUnderlyingNetworks() {
        val network = DefaultNetworkMonitor.defaultNetwork
        if (network != null) {
            setUnderlyingNetworks(arrayOf(network))
        } else {
            // null tells Android to use the system default
            setUnderlyingNetworks(null)
        }
    }

    private fun serviceCleanUp() {
        AppLogger.d(TAG, "Cleaning up service")
        VpnStatusManager.unregisterVPNStatusReceiver(this)
        MainActivity.receiverRegistered = false
    }

    private fun createVPNBuilder(options: TunOptions): Builder {
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
        val opts =
            Opts().apply {
                dataDir = initConfigDir()
                logDir = logDir()
                logLevel = "trace"
                deviceid = DeviceUtil.deviceId()
                locale = DeviceUtil.getLanguageCode(this@LanternVpnService)
                telemetryConsent = isTelemetryEnabled()
                env = getRadianceEnv()
                platform = this@LanternVpnService
            }
        return opts
    }
}
