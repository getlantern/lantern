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
import java.util.concurrent.atomic.AtomicBoolean

open class NoVpnLanternService : Service(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "NoVpnLanternService"
        const val ACTION_START_PROXY = "org.getlantern.START_LOCAL_PROXY"
        const val ACTION_CONNECT_TO_SERVER = "org.getlantern.LOCAL_PROXY_CONNECT_TO_SERVER"
        const val ACTION_STOP_PROXY = "org.getlantern.STOP_LOCAL_PROXY"
        private const val PROXY_START_TIMEOUT_MS = 60_000L
        private const val PROXY_NOTIFICATION_ID = 8787
        private const val PROXY_CHANNEL_ID = "local_connection"
        private val connectInFlight = AtomicBoolean(false)
        private val stopPending = AtomicBoolean(false)
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private val flutterEventListener = FlutterEventListener()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_STOP_PROXY -> {
                serviceScope.launch { stopProxy() }
                START_NOT_STICKY
            }

            ACTION_CONNECT_TO_SERVER -> {
                showProxyNotification("Starting local connection")
                serviceScope.launch { connectToServer(intent.getStringExtra("tag") ?: "") }
                START_STICKY
            }

            else -> {
                showProxyNotification("Starting local connection")
                serviceScope.launch { startProxy() }
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        runBlocking(Dispatchers.IO) {
            cleanupProxy(stopService = false)
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    private suspend fun startProxy() = withContext(Dispatchers.IO) {
        VpnStatusManager.postVPNStatus(VPNStatus.Connecting)
        val started = runBlockingMobileOperation(
            errorCode = "start_proxy",
            errorMessage = "Failed to start local proxy",
        ) {
            configureProxyEnv()
            if (!Mobile.isRadianceConnected()) {
                Mobile.startIPCServer(this@NoVpnLanternService, opts())
                Mobile.setupRadiance(opts(), flutterEventListener)
            }
            DefaultNetworkMonitor.start()
            // Radiance exposes its no-VPN SOCKS/HTTP CONNECT listener through
            // the existing connect path when RADIANCE_USE_SOCKS_PROXY is set.
            Mobile.startVPN()
        }
        if (started) {
            if (stopIfPending()) {
                return@withContext
            }
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            showProxyNotification("Local connection active")
            AppLogger.i(TAG, "Local proxy started at ${proxyAddress()}")
        }
    }

    private suspend fun stopProxy() = withContext(Dispatchers.IO) {
        if (!connectInFlight.compareAndSet(false, true)) {
            AppLogger.d(TAG, "Local proxy operation already in flight; deferring stop")
            stopPending.set(true)
            VpnStatusManager.postVPNStatus(VPNStatus.Disconnecting)
            return@withContext
        }
        try {
            cleanupProxy(stopService = true)
        } finally {
            connectInFlight.set(false)
        }
    }

    private suspend fun cleanupProxy(stopService: Boolean) = withContext(Dispatchers.IO) {
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
        VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
        stopForeground(STOP_FOREGROUND_REMOVE)
        if (stopService) {
            stopSelf()
        }
    }

    private suspend fun connectToServer(tag: String) = withContext(Dispatchers.IO) {
        VpnStatusManager.postVPNStatus(VPNStatus.Connecting)
        if (!startProxyForConnect()) {
            return@withContext
        }
        val connected = runBlockingMobileOperation(
            errorCode = "connect_proxy_server",
            errorMessage = "Failed to switch local proxy server",
        ) {
            Mobile.connectToServer(tag)
        }
        if (connected) {
            if (stopIfPending()) {
                return@withContext
            }
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            showProxyNotification("Local connection active")
        }
    }

    private suspend fun startProxyForConnect(): Boolean {
        if (Mobile.isRadianceConnected()) {
            return true
        }
        startProxy()
        return Mobile.isRadianceConnected()
    }

    private suspend fun runBlockingMobileOperation(
        errorCode: String,
        errorMessage: String,
        block: suspend () -> Unit,
    ): Boolean {
        if (!connectInFlight.compareAndSet(false, true)) {
            val error = IllegalStateException("previous local proxy operation still in flight")
            AppLogger.e(TAG, errorMessage, error)
            VpnStatusManager.postVPNError(errorCode, errorMessage, error)
            if (Mobile.isRadianceConnected()) {
                showProxyNotification("Local connection active")
            } else {
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            return false
        }

        val connectScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        val deferred = connectScope.async { block() }
        deferred.invokeOnCompletion {
            connectInFlight.set(false)
            connectScope.cancel()
        }

        return try {
            withTimeout(PROXY_START_TIMEOUT_MS) { deferred.await() }
            true
        } catch (e: TimeoutCancellationException) {
            AppLogger.e(TAG, "$errorMessage timed out after ${PROXY_START_TIMEOUT_MS}ms", e)
            VpnStatusManager.postVPNError("${errorCode}_timeout", "$errorMessage timed out", e)
            cleanupProxy(stopService = true)
            false
        } catch (e: Exception) {
            AppLogger.e(TAG, errorMessage, e)
            VpnStatusManager.postVPNError(errorCode, errorMessage, e)
            cleanupProxy(stopService = true)
            false
        }
    }

    private suspend fun stopIfPending(): Boolean {
        if (!stopPending.getAndSet(false)) {
            return false
        }
        cleanupProxy(stopService = true)
        return true
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
        runBlocking(Dispatchers.IO) {
            cleanupProxy(stopService = false)
            startProxy()
            if (!Mobile.isRadianceConnected()) {
                val msg = "restartService failed: local proxy not connected after restart"
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

    override fun writeLog(message: String?) {
        AppLogger.d(TAG, "writeLog: $message")
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
