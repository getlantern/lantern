package org.getlantern.lantern.service

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.system.Os
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import lantern.io.libbox.Notification
import lantern.io.libbox.StringIterator
import lantern.io.libbox.TunOptions
import lantern.io.mobile.Mobile
import lantern.io.utils.Opts
import org.getlantern.lantern.BuildConfig
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.DeviceUtil
import org.getlantern.lantern.utils.FlutterEventListener
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.getRadianceEnv
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.isTelemetryEnabled
import org.getlantern.lantern.utils.logDir

class NoVpnLanternService : Service(), PlatformInterfaceWrapper {
    companion object {
        private const val TAG = "NoVpnLanternService"
        const val ACTION_START_PROXY = "org.getlantern.START_LOCAL_PROXY"
        const val ACTION_CONNECT_TO_SERVER = "org.getlantern.LOCAL_PROXY_CONNECT_TO_SERVER"
        const val ACTION_STOP_PROXY = "org.getlantern.STOP_LOCAL_PROXY"
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
                serviceScope.launch { connectToServer(intent.getStringExtra("tag") ?: "") }
                START_STICKY
            }

            else -> {
                serviceScope.launch { startProxy() }
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        serviceScope.cancel()
        super.onDestroy()
    }

    private suspend fun startProxy() = withContext(Dispatchers.IO) {
        runCatching {
            configureProxyEnv()
            if (!Mobile.isRadianceConnected()) {
                Mobile.startIPCServer(this@NoVpnLanternService, opts())
                Mobile.setupRadiance(opts(), flutterEventListener)
            }
            // Radiance exposes its no-VPN SOCKS/HTTP CONNECT listener through
            // the existing connect path when RADIANCE_USE_SOCKS_PROXY is set.
            Mobile.startVPN()
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
            AppLogger.i(TAG, "Local proxy started at ${proxyAddress()}")
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to start local proxy", e)
            VpnStatusManager.postVPNError(
                errorCode = "start_proxy",
                errorMessage = "Failed to start local proxy",
                error = e,
            )
        }
    }

    private suspend fun stopProxy() = withContext(Dispatchers.IO) {
        runCatching {
            if (Mobile.isRadianceConnected()) {
                Mobile.stopVPN()
            }
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to stop local proxy", e)
        }
        VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
        stopSelf()
    }

    private suspend fun connectToServer(tag: String) = withContext(Dispatchers.IO) {
        startProxy()
        runCatching {
            Mobile.connectToServer(tag)
            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
        }.onFailure { e ->
            AppLogger.e(TAG, "Failed to switch local proxy server", e)
            VpnStatusManager.postVPNError(
                errorCode = "connect_proxy_server",
                errorMessage = "Failed to switch local proxy server",
                error = e,
            )
        }
    }

    private fun configureProxyEnv() {
        Os.setenv("RADIANCE_USE_SOCKS_PROXY", "true", true)
        Os.setenv("RADIANCE_SOCKS_ADDRESS", proxyAddress(), true)
    }

    private fun proxyAddress(): String {
        return "${BuildConfig.STEALTH_NO_VPN_PROXY_HOST}:${BuildConfig.STEALTH_NO_VPN_PROXY_PORT}"
    }

    override fun openTun(tunOptions: TunOptions): Int {
        error("TUN is disabled in stealth no-VPN builds")
    }

    override fun autoDetectInterfaceControl(fd: Int) {
    }

    override fun postServiceClose() {
    }

    override fun restartService() {
        serviceScope.launch {
            stopProxy()
            startProxy()
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
