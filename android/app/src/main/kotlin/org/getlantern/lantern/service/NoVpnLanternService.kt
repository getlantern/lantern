package org.getlantern.lantern.service

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.system.Os
import androidx.core.app.NotificationCompat
import java.util.concurrent.TimeoutException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineExceptionHandler
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import lantern.io.libbox.Notification
import lantern.io.libbox.StringIterator
import lantern.io.libbox.TunOptions
import lantern.io.mobile.Mobile
import lantern.io.utils.Opts
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.R
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.DeviceUtil
import org.getlantern.lantern.utils.FlutterEventListener
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.getRadianceEnv
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.isTelemetryEnabled
import org.getlantern.lantern.utils.logDir

open class NoVpnLanternService : Service(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "NoVpnLanternService"
        const val ACTION_START_RADIANCE = "org.getlantern.START_LOCAL_BACKEND"
        const val ACTION_START_PROXY = "org.getlantern.START_LOCAL_PROXY"
        const val ACTION_CONNECT_TO_SERVER = "org.getlantern.LOCAL_PROXY_CONNECT_TO_SERVER"
        const val ACTION_STOP_PROXY = "org.getlantern.STOP_LOCAL_PROXY"
        private const val PROXY_START_TIMEOUT_MS = 60_000L
        private const val PROXY_NOTIFICATION_ID = 8787
        private const val PROXY_CHANNEL_ID = "local_connection"

        // Starts, restarts, and stops share one gate so a stop waits for any
        // native start to return before tearing the listener down.
        private val proxyStartGate = VpnStartGate()

        // Teardown outlives the service instance and must stay off the main
        // thread: Mobile.stopVPN() can block on IPC.
        private val teardownScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    }

    private val serviceScope =
        CoroutineScope(
            Dispatchers.IO + SupervisorJob() +
                CoroutineExceptionHandler { _, e ->
                    AppLogger.e(TAG, "Uncaught exception in service coroutine", e)
                    VpnStatusManager.postVPNError(
                        errorCode = "service_coroutine_uncaught",
                        errorMessage = "Unexpected local proxy service error",
                        error = e,
                    )
                },
        )
    private val flutterEventListener = FlutterEventListener()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_START_RADIANCE -> {
                serviceScope.launch { startBackend() }
                START_NOT_STICKY
            }

            ACTION_STOP_PROXY -> {
                serviceScope.launch { stopProxy() }
                START_NOT_STICKY
            }

            ACTION_CONNECT_TO_SERVER -> {
                showProxyNotification("Starting local connection")
                val tag = intent.getStringExtra("tag") ?: ""
                serviceScope.launch {
                    launchProxy(errorCode = "connect_proxy_server") { Mobile.connectToServer(tag) }
                }
                START_STICKY
            }

            else -> {
                showProxyNotification("Starting local connection")
                serviceScope.launch {
                    launchProxy(errorCode = "start_proxy") { Mobile.startVPN() }
                }
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        try {
            teardownScope.launch {
                proxyStartGate.stop {
                    stopProxyListener()
                    VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                }
            }
        } finally {
            serviceScope.cancel()
            super.onDestroy()
        }
    }

    private suspend fun startBackend() {
        try {
            withContext(Dispatchers.IO) { setupBackend() }
            AppLogger.d(TAG, "Radiance setup completed")
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error in Radiance setup", e)
        }
    }

    private suspend fun setupBackend() {
        configureProxyEnv()
        RadianceSetup.setup(this@NoVpnLanternService, ::opts, flutterEventListener)
    }

    /**
     * Runs one start, server switch, or restart through [proxyStartGate].
     * Returns false when the gate rejected the request.
     */
    private suspend fun launchProxy(
        errorCode: String,
        restart: Boolean = false,
        connect: () -> Unit,
    ): Boolean = withContext(Dispatchers.IO) {
        proxyStartGate.run(
            waitForIdle = restart,
            onRejected = { rejection ->
                AppLogger.i(TAG, "Local proxy operation ($errorCode) ignored: $rejection")
                // The running stop owns teardown; drop only this request's notification.
                if (rejection == VpnStartGate.Rejection.STOPPING) {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                }
            },
        ) { attempt ->
            try {
                attempt.publish { VpnStatusManager.postVPNStatus(VPNStatus.Connecting) }
                setupBackend()
                if (restart) stopProxyListener()
                DefaultNetworkMonitor.start()
                attempt.connect(
                    PROXY_START_TIMEOUT_MS,
                    onTimeout = {
                        reportProxyError(errorCode, TimeoutException("Local proxy operation timed out"))
                    },
                    connect = connect,
                )
                // Startup can report failure without throwing.
                check(Mobile.isVPNConnected()) { "Local proxy is not running after $errorCode" }
                attempt.publish {
                    VpnStatusManager.postVPNStatus(VPNStatus.Connected)
                    showProxyNotification("Local connection active")
                }
                AppLogger.i(TAG, "Local proxy running at ${proxyAddress()}")
            } catch (e: Exception) {
                if (e !is CancellationException) {
                    attempt.publish { reportProxyError(errorCode, e) }
                }
                // A failed server switch can leave the previous listener running.
                val mayBeRunning = try {
                    Mobile.isVPNConnected()
                } catch (statusError: CancellationException) {
                    throw statusError
                } catch (_: Exception) {
                    true
                }
                if (!mayBeRunning) {
                    runCatching { DefaultNetworkMonitor.stop() }
                        .onFailure { err -> AppLogger.e(TAG, "Failed to stop default network monitor", err) }
                    stopForeground(STOP_FOREGROUND_REMOVE)
                }
                if (e is CancellationException) throw e
            }
        }
    }

    private suspend fun stopProxy() {
        proxyStartGate.stop(onStopping = { VpnStatusManager.postVPNStatus(VPNStatus.Disconnecting) }) {
            stopProxyListener()
            VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        }
    }

    /** Stops the listener and network monitor; keeps the backend up. */
    private suspend fun stopProxyListener() {
        runCatching {
            if (Mobile.isRadianceConnected()) {
                Mobile.stopVPN()
            }
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to stop local proxy", e)
        }
        runCatching {
            DefaultNetworkMonitor.stop()
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to stop default network monitor", e)
        }
    }

    private fun reportProxyError(errorCode: String, error: Exception) {
        val timedOut = error is TimeoutException
        if (timedOut) {
            AppLogger.e(TAG, "Local proxy operation ($errorCode) timed out after ${PROXY_START_TIMEOUT_MS}ms", error)
        } else {
            AppLogger.e(TAG, "Error in local proxy operation ($errorCode)", error)
        }
        VpnStatusManager.postVPNError(
            errorCode = if (timedOut) "${errorCode}_timeout" else errorCode,
            errorMessage = if (timedOut) "Local proxy operation timed out" else "Error in local proxy operation",
            error = error,
        )
    }

    private fun configureProxyEnv() {
        // Apply via Go (Mobile.setLocalProxy), NOT Os.setenv: radiance reads these
        // through Go's os.LookupEnv, and the Go runtime's env cache does not
        // observe libc setenv() calls made from Kotlin. Setting them from Kotlin
        // leaves RADIANCE_USE_SOCKS_PROXY invisible to radiance, so sing-box binds
        // the default bypass inbound instead of this SOCKS listener. See
        // Mobile.SetLocalProxy.
        Mobile.setLocalProxy(true, proxyAddress())
    }

    private fun proxyAddress(): String {
        // The user-editable listen port arrives via RADIANCE_PROXY_LISTEN_PORT
        // (Mobile.setProxyListenPort, driven by the Dart proxy-port setting);
        // fall back to the build-time default when unset/invalid.
        val port = Os.getenv("RADIANCE_PROXY_LISTEN_PORT")
            ?.toIntOrNull()
            ?.takeIf { it in 1..65535 }
            ?: BuildConfig.STEALTH_NO_VPN_PROXY_PORT
        return "${BuildConfig.STEALTH_NO_VPN_PROXY_HOST}:$port"
    }

    override fun openTun(tunOptions: TunOptions): Int {
        error("TUN is disabled in stealth no-VPN builds")
    }

    // No-VPN builds run no TUN, so there is no tunnel to protect outbound sockets
    // from. Returning false makes sing-box bind outbound sockets to the default
    // interface through its own Go-side control (driven by the ConnectivityManager
    // interface monitor) instead of invoking the per-socket platform
    // AutoDetectInterfaceControl JNI callback on every dial. That per-socket
    // callback crashes gomobile's seq layer ("Unknown reference" /
    // go_seq_from_refnum SIGABRT) under the high call volume of direct dialing;
    // the VPN build doesn't hit this because its traffic flows through the TUN.
    override fun usePlatformAutoDetectInterfaceControl(): Boolean {
        return false
    }

    override fun autoDetectInterfaceControl(fd: Int) {
    }

    override fun postServiceClose() {
    }

    override fun restartService() {
        AppLogger.i(TAG, "restartService called")
        // Radiance treats a normal return as a completed restart.
        runBlocking(Dispatchers.IO) {
            val accepted = launchProxy(errorCode = "restart_proxy", restart = true) { Mobile.startVPN() }
            check(accepted) { "Local proxy restart was superseded by a stop request" }
            if (!Mobile.isVPNConnected()) {
                val msg = "restartService failed: local proxy not running after restart"
                AppLogger.e(TAG, msg)
                throw IllegalStateException(msg)
            }
        }
        AppLogger.i(TAG, "restartService completed")
    }

    override fun sendNotification(notification: Notification?) {
    }

    private fun showProxyNotification(text: String) {
        createProxyNotificationChannel()
        startForeground(PROXY_NOTIFICATION_ID, buildProxyNotification(text))
    }

    private fun buildProxyNotification(text: String): android.app.Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, PROXY_CHANNEL_ID)
            .setSmallIcon(R.drawable.lantern_notification_icon)
            .setContentTitle(getString(R.string.app_name))
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createProxyNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val channel = NotificationChannel(
            PROXY_CHANNEL_ID,
            "Connection",
            NotificationManager.IMPORTANCE_LOW,
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    override fun systemCertificates(): StringIterator {
        return object : StringIterator {
            override fun hasNext(): Boolean = false
            override fun len(): Int = 0
            override fun next(): String = ""
        }
    }

    fun opts(): Opts {
        return Opts().apply {
            dataDir = initConfigDir()
            logDir = logDir()
            logLevel = "trace"
            deviceid = DeviceUtil.deviceId()
            locale = DeviceUtil.getLanguageCode(this@NoVpnLanternService)
            telemetryConsent = isTelemetryEnabled()
            env = getRadianceEnv()
            platform = this@NoVpnLanternService
        }
    }
}
