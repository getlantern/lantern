package org.getlantern.lantern.service

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import java.util.concurrent.TimeoutException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
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

        private const val UPGRADE_RESET_PREFS = "vpn_upgrade_reset"
        private const val LAST_RESET_APK_UPDATE_TIME = "last_reset_apk_update_time"
        private const val UPGRADE_RESET_SETTLE_MS = 250L

        // Limit how long the UI waits for a blocking native start.
        private const val VPN_START_TIMEOUT_MS = 60_000L

        private val vpnStartGate = VpnStartGate()

        private sealed class RadianceState {
            data object Initializing : RadianceState()
            data object Ready : RadianceState()
            data class Failed(val cause: Throwable) : RadianceState()
        }

        private val radianceState = MutableStateFlow<RadianceState>(RadianceState.Initializing)
        private val radianceSetupMutex = Mutex()

        suspend fun awaitRadianceReady() {
            if (Mobile.isRadianceConnected()) return
            when (val state = radianceState.first { it !is RadianceState.Initializing }) {
                RadianceState.Ready -> check(Mobile.isRadianceConnected()) {
                    "Radiance setup completed but the core is unavailable"
                }
                is RadianceState.Failed -> throw state.cause
                RadianceState.Initializing -> error("Radiance is still initializing")
            }
        }

        lateinit var instance: LanternVpnService

        // Process-lifetime scope for teardown that must run off the main thread
        // but outlive the service instance. Mobile.stopVPN() is a blocking JNI
        // call; running it on the main thread in onDestroy ANRs during service
        // teardown (getlantern/engineering#3563). serviceScope is cancelled in
        // onDestroy's finally, so teardown can't live there — this scope is
        // never cancelled.
        private val teardownScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
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
    //
    // SupervisorJob keeps one child's failure from cancelling its siblings, but it does
    // not handle the exception: without a CoroutineExceptionHandler an uncaught throw in
    // any launch{} below reaches the thread's default handler and takes the process down
    // with no Kotlin log and no Go crash file, which reads as a silent death. The handler
    // makes that case diagnosable and reports it to the UI like any other VPN error.
    private val serviceScope =
        CoroutineScope(
            Dispatchers.IO + SupervisorJob() +
                CoroutineExceptionHandler { _, e ->
                    AppLogger.e(TAG, "Uncaught exception in service coroutine", e)
                    VpnStatusManager.postVPNError(
                        errorCode = "service_coroutine_uncaught",
                        errorMessage = "Unexpected VPN service error",
                        error = e,
                    )
                },
        )

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
                    startVPN()
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
            // Only the TUN fd close stays synchronous on the main thread — it's
            // cheap and the OS should release the interface promptly.
            closeTunInterface()

            // Native teardown can block. Keep it off the main thread and let it
            // outlive serviceScope; the gate waits for any native start to finish.
            teardownScope.launch {
                vpnStartGate.stop {
                    runCatching {
                        if (Mobile.isRadianceConnected()) {
                            Mobile.stopVPN()
                            AppLogger.d(TAG, "stopVPN completed during destroy")
                        } else {
                            AppLogger.d(TAG, "Skipping stopVPN — Radiance IPC not running")
                        }
                    }.onFailure { e -> AppLogger.e(TAG, "Mobile.stopVPN() failed during destroy", e) }

                    runCatching { DefaultNetworkMonitor.stop() }
                        .onFailure { e -> AppLogger.e(TAG, "DefaultNetworkMonitor.stop() failed during destroy", e) }

                    notificationHelper.stopVPNConnectedNotification(this@LanternVpnService)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        QuickTileService.triggerUpdateTileState(this@LanternVpnService, false)
                    }
                    serviceCleanUp()
                }
            }
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
        // Android normally tears the previous TUN down when a new VPN is
        // established, but explicitly dropping our fd first prevents a stale
        // descriptor from surviving restarts or app-upgrade recovery.
        closeTunInterface()
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
        // Radiance treats a successful return as a completed restart, so wait
        // for teardown and startup. It releases its mutex before this callback,
        // which lets us call back into Mobile without deadlocking (#3297).
        runBlocking(Dispatchers.IO) {
            val accepted = launchVPN(errorCode = "restart_vpn", restart = true) { Mobile.startVPN() }
            check(accepted) { "VPN restart was superseded by a stop request" }
            // Startup reports recoverable failures without throwing. Radiance
            // needs an error here if the tunnel did not actually restart.
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

    private suspend fun startRadiance() {
        try {
            withContext(Dispatchers.IO) {
                setupRadiance()
            }
            AppLogger.d(TAG, "Radiance setup completed")
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error in Radiance setup", e)
        }
    }

    private suspend fun setupRadiance() {
        radianceSetupMutex.withLock {
            if (Mobile.isRadianceConnected()) {
                radianceState.value = RadianceState.Ready
                return@withLock
            }

            radianceState.value = RadianceState.Initializing
            try {
                Mobile.startIPCServer(this@LanternVpnService, opts())
                Mobile.setupRadiance(opts(), flutterEventListener)
                radianceState.value = RadianceState.Ready
            } catch (e: Exception) {
                radianceState.value = RadianceState.Failed(e)
                throw e
            }
        }
    }

    suspend fun startVPN() {
        launchVPN(errorCode = "start_vpn") {
            Mobile.startVPN()
            AppLogger.d(TAG, "VPN service started")
        }
    }

    suspend fun connectToServer(
        tag: String,
    ) {
        launchVPN(errorCode = "connect_to_server") {
            Mobile.connectToServer(tag)
            AppLogger.d(TAG, "Connected to server")
        }
    }

    private suspend fun launchVPN(
        errorCode: String,
        restart: Boolean = false,
        connect: () -> Unit,
    ) = withContext(Dispatchers.IO) {
        // A duplicate may also arrive via startForegroundService, so promote the
        // service before deciding which request owns startup.
        val foregroundFailure = try {
            notificationHelper.showStartingVPNConnectedNotification(this@LanternVpnService)
            null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            e
        }
        val accepted = vpnStartGate.run(waitForIdle = restart) { attempt ->
            try {
                if (prepare(this@LanternVpnService) != null) {
                    attempt.publish { VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission) }
                    cleanUpFailedVPNStart()
                    stopSelf()
                    return@run
                }
                if (foregroundFailure != null) throw foregroundFailure
                attempt.publish { VpnStatusManager.postVPNStatus(VPNStatus.Connecting) }
                if (!Mobile.isRadianceConnected()) {
                    AppLogger.d(TAG, "Radiance not ready, setting up before VPN start")
                    setupRadiance()
                }
                if (restart) stopVPNTunnel()
                resetVpnAfterAppUpgradeIfNeeded()
                DefaultNetworkMonitor.setNetworkChangeCallback { updateUnderlyingNetworks() }
                DefaultNetworkMonitor.start()
                updateUnderlyingNetworks()
                attempt.connect(
                    VPN_START_TIMEOUT_MS,
                    onTimeout = {
                        reportVPNStartError(errorCode, TimeoutException("VPN operation timed out"))
                    },
                    connect = connect,
                )
                attempt.publish {
                    VpnStatusManager.postVPNStatus(VPNStatus.Connected)
                    notificationHelper.showVPNConnectedNotification(this@LanternVpnService)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        QuickTileService.triggerUpdateTileState(this@LanternVpnService, true)
                    }
                }
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    attempt.publish { reportVPNStartError(errorCode, e) }
                }
                // JNI has finished, but a failed server switch can leave the
                // previous tunnel connected and still using the monitor.
                val mayBeConnected = try {
                    Mobile.isVPNConnected()
                } catch (statusError: CancellationException) {
                    throw statusError
                } catch (_: Exception) {
                    true
                }
                if (!mayBeConnected) {
                    cleanUpFailedVPNStart()
                    if (foregroundFailure != null) stopSelf()
                }
                if (e is CancellationException) throw e
            }
        }
        if (!accepted) {
            AppLogger.i(TAG, "VPN operation ($errorCode) ignored: another start or stop is in progress")
        }
        accepted
    }

    private fun reportVPNStartError(errorCode: String, error: Exception) {
        val timedOut = error is TimeoutException
        if (timedOut) {
            AppLogger.e(TAG, "VPN operation ($errorCode) timed out after ${VPN_START_TIMEOUT_MS}ms", error)
        } else {
            AppLogger.e(TAG, "Error in VPN operation ($errorCode)", error)
        }
        VpnStatusManager.postVPNError(
            errorCode = if (timedOut) "${errorCode}_timeout" else errorCode,
            errorMessage = if (timedOut) "VPN operation timed out" else "Error in VPN operation",
            error = error,
        )
    }

    private suspend fun cleanUpFailedVPNStart() = withContext(NonCancellable) {
        try {
            DefaultNetworkMonitor.stop()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            AppLogger.e(TAG, "DefaultNetworkMonitor.stop() failed in error path", e)
        }
        notificationHelper.stopVPNConnectedNotification(this@LanternVpnService)
        serviceCleanUp()
    }

    private suspend fun resetVpnAfterAppUpgradeIfNeeded() {
        if (!consumeUpgradeResetMarker()) return

        // An APK update kills the old process, but the Android VPN profile and
        // app-private native state persist across the upgrade. Reset once on the
        // first tunnel start after the new process comes up.
        AppLogger.i(TAG, "App APK updated; resetting VPN state before first tunnel start")
        stopVPNTunnel()
        delay(UPGRADE_RESET_SETTLE_MS)
    }

    private fun consumeUpgradeResetMarker(): Boolean {
        val packageInfo = currentPackageInfo()
        val currentApkUpdateTime = packageInfo.lastUpdateTime
        val prefs = getSharedPreferences(UPGRADE_RESET_PREFS, Context.MODE_PRIVATE)
        val lastResetApkUpdateTime = prefs.getLong(LAST_RESET_APK_UPDATE_TIME, Long.MIN_VALUE)
        if (lastResetApkUpdateTime == currentApkUpdateTime) {
            return false
        }

        prefs.edit().putLong(LAST_RESET_APK_UPDATE_TIME, currentApkUpdateTime).apply()
        if (packageInfo.lastUpdateTime <= packageInfo.firstInstallTime) {
            AppLogger.d(TAG, "Recording initial APK install for VPN upgrade reset")
            return false
        }

        AppLogger.i(
            TAG,
            "VPN upgrade reset needed: lastResetApkUpdateTime=$lastResetApkUpdateTime currentApkUpdateTime=$currentApkUpdateTime versionCode=${packageVersionCode(packageInfo)}",
        )
        return true
    }

    private fun currentPackageInfo(): PackageInfo {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.PackageInfoFlags.of(0),
            )
        } else {
            @Suppress("DEPRECATION")
            packageManager.getPackageInfo(packageName, 0)
        }
    }

    private fun packageVersionCode(info: PackageInfo): Long {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            @Suppress("DEPRECATION")
            info.versionCode.toLong()
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
        vpnStartGate.stop(onStopping = { VpnStatusManager.postVPNStatus(VPNStatus.Disconnecting) }) {
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
                appVersion = BuildConfig.VERSION_NAME
                locale = DeviceUtil.getLanguageCode(this@LanternVpnService)
                telemetryConsent = isTelemetryEnabled()
                env = getRadianceEnv()
                platform = this@LanternVpnService
            }
        return opts
    }
}
