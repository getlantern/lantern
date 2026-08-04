package org.getlantern.lantern

import android.Manifest
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import lantern.io.mobile.Mobile
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.handler.EventHandler
import org.getlantern.lantern.handler.MethodHandler
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.QuickTileService
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.initConfigDir
import org.getlantern.lantern.utils.isServiceRunning
import org.getlantern.lantern.utils.logDir
import org.getlantern.lantern.utils.setupDirs


class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val TAG = "A/MainActivity"
        lateinit var instance: MainActivity
        const val VPN_PERMISSION_REQUEST_CODE = 7777
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1010

        // Tombstones and ANR traces run to hundreds of KB; enough to identify the
        // faulting frame without displacing the rest of an attached log bundle.
        private const val MAX_EXIT_TRACE_CHARS = 20_000
        var receiverRegistered: Boolean = false
        var pendingServiceStart: Boolean = false
        var isEngineConfigured: Boolean = false

        private var retryCount = 0
        private val maxRetries = 5
        private val maxRetriesResume = 5
        private var retryCountResume = 0


    }

    private val RETRY_DELAY_MS = 2000L // 2 seconds

    private val serviceStartHandler = Handler(Looper.getMainLooper())

    // Pending tag replayed after the VPN-consent dialog so consent can't collapse the
    // selection into auto. Null = auto.
    @Volatile
    private var pendingTag: String? = null


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (isEngineConfigured) {
            Log.d(TAG, "FlutterEngine already configured, skipping")
            return
        }
        instance = this
        setupDirs()
        Log.d(TAG, "Config directories set up")
        AppLogger.init()
        AppLogger.d(TAG, "AppLogger initialized")
        logPreviousExitReasons()
        // Wire up Go-side logging before any Mobile.* call. Without this, every
        // lantern-core / radiance slog call that fires before LanternVpnService's
        // ACTION_START_RADIANCE coroutine reaches common.Init falls through to
        // the stdlib default (text → stderr → logcat at INFO), so DEBUG logs
        // disappear and the format diverges from the rest. common.Init is
        // idempotent — the later call from backend.NewLocalBackend is a no-op.
        try {
            Mobile.initLogging(initConfigDir(), logDir(), "trace")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to init Go logging: ${e.message}")
        }
        ///Setup handler
        flutterEngine.plugins.add(EventHandler())
        flutterEngine.plugins.add(MethodHandler())
        startLanternService()
        isEngineConfigured = true
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        isEngineConfigured = false
    }


    override fun onResume() {
        super.onResume()
        // Check if there is a pending service start
        if (pendingServiceStart && retryCountResume < maxRetriesResume) {
            retryCountResume++
            AppLogger.d(TAG, "Retrying pending service start")
            startLanternService()
        }
    }

    private fun startLanternService() {
        AppLogger.d(TAG, "Starting LanternService")
        if (isServiceRunning(this, LanternVpnService::class.java)) {
            AppLogger.d(TAG, "LanternService is already running")
            return
        }
        try {
            val radianceIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_START_RADIANCE
            }
            startService(radianceIntent)
            AppLogger.d(TAG, "LanternService started")
            pendingServiceStart = false
            retryCount = 0
            retryCountResume = 0
        } catch (e: IllegalStateException) {
            AppLogger.e(TAG, "Cannot start service in background: ${e.message}")
            // App is in background, schedule for when app comes to foreground
            pendingServiceStart = true
        } catch (e: Exception) {
            e.printStackTrace()
            AppLogger.e(TAG, "Error starting LanternService", e)
            // Got some issue starting service, schedule immediate retry
            handleImmediateRetry()
        }
    }

    private fun handleImmediateRetry() {
        AppLogger.d(TAG, "Handling immediate retry for LanternService start")
        if (retryCount < maxRetries) {
            retryCount++
            val delay = RETRY_DELAY_MS * retryCount // Exponential backoff

            AppLogger.d(TAG, "Scheduling immediate retry #$retryCount in ${delay}ms")
            serviceStartHandler.postDelayed({
                startLanternService()
            }, delay)
        } else {
            /*
            * We tried multiple times but failed
            * In between user screen might go off to background
            * Will wait user it comes back*/

            AppLogger.e(TAG, "Max retries ($maxRetries) reached. Service start failed.")
            // Optionally notify user or handle failure
            // Wait for app to come to foreground
            pendingServiceStart = true
        }
    }


    fun startVPN() {
        pendingTag = null
        if (!isVPNServiceReady()) {
            AppLogger.d(TAG, "VPN service not ready")
            return
        }

        // Check if VPN is already connected
        // if so then user already have vpn on now wish to switch server
        // Do not need to create service again just switch server
        if (Mobile.isVPNConnected()) {
            AppLogger.d(TAG, "VPN is already connected, switching auto server")
            CoroutineScope(Dispatchers.Main).launch {
                LanternVpnService.instance.connectToServer("auto")
            }
            return
        }

        try {
            val vpnIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_START_VPN
            }
            ContextCompat.startForegroundService(this, vpnIntent)
            AppLogger.d(TAG, "VPN service started")
        } catch (e: Exception) {
            e.printStackTrace()
            AppLogger.e(TAG, "Error starting VPN service", e)
            throw e
        }
    }

    fun connectToServer(tag: String) {
        if (!isVPNServiceReady()) {
            // Preserve the selection across the consent dialog; resumePendingConnect replays it.
            pendingTag = tag
            AppLogger.d(TAG, "VPN service not ready")
            return
        }
        // Check if VPN is already connected
        // if so then user already have vpn on now wish to switch server
        // Do not need to create service again just switch server

        if (Mobile.isVPNConnected()) {
            AppLogger.d(TAG, "VPN is already connected, switching server")
            CoroutineScope(Dispatchers.Main).launch {
                LanternVpnService.instance.connectToServer(tag)
            }
            pendingTag = null
            return
        }

        try {
            val vpnIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_CONNECT_TO_SERVER
                putExtra("tag", tag)
            }
            ContextCompat.startForegroundService(this, vpnIntent)
            AppLogger.d(TAG, "VPN service started")
            // Clear only after a successful dispatch so a failed start keeps it for retry.
            pendingTag = null
        } catch (e: Exception) {
            e.printStackTrace()
            AppLogger.e(TAG, "Error starting VPN service", e)
            throw e
        }
    }


    // Replays the pending selection after VPN consent, so consent doesn't fall back to auto.
    private fun resumePendingConnect() {
        val tag = pendingTag
        if (tag != null) {
            connectToServer(tag)
        } else {
            startVPN()
        }
    }

    fun stopVPN() {
        if (isServiceRunning(this, LanternVpnService::class.java)) {
            LanternApp.application.sendBroadcast(
                Intent(LanternVpnService.ACTION_STOP_VPN)
                    .setPackage(LanternApp.application.packageName)
            )
            return
        }

        // service isn’t up.. stop core directly and publish status
        CoroutineScope(Dispatchers.Main).launch {
            try {
                runCatching { Mobile.stopVPN() }
                // notify quick tile and update UI state
                VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    QuickTileService.triggerUpdateTileState(this@MainActivity, false)
                }
            } catch (e: Exception) {
                AppLogger.e(TAG, "stopVPN failed", e)
            }
        }
    }

    private fun isVPNServiceReady(): Boolean {
        try {
            val intent = VpnService.prepare(this)
            if (intent != null) {
                startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
                return false;
            } else {
                return true;
            }
        } catch (e: Exception) {
            AppLogger.e(TAG, "Error preparing VPN service", e)
            return false
        }
    }


    override fun onDestroy() {
        super.onDestroy()

    }


    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            if (resultCode == RESULT_OK) {
                resumePendingConnect()
            } else {
                VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            }
        }
    }

    private fun askNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST_CODE
            )
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        if (requestCode == NOTIFICATION_PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                resumePendingConnect()
            } else {
                VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * Logs how previous processes died, as reported by the OS.
     *
     * A process killed by the system — an uncaught exception on a thread with no
     * handler, a foreground-service deadline, a native abort, low memory — leaves
     * nothing behind in our own logs, so a bug report shows a truncated file that
     * simply stops. [android.app.ActivityManager.getHistoricalProcessExitReasons]
     * is the OS's record of what happened, and reading it on the next launch is
     * the only way that reason reaches an attached log bundle.
     *
     * Runs after AppLogger.init() so the output lands in lantern.log rather than
     * only logcat, which users cannot capture.
     */
    private fun logPreviousExitReasons() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        try {
            val am = getSystemService(ActivityManager::class.java) ?: return
            val exits = am.getHistoricalProcessExitReasons(packageName, 0, 5)
            if (exits.isEmpty()) {
                AppLogger.d(TAG, "No previous process exits recorded")
                return
            }
            for (info in exits) {
                AppLogger.i(
                    TAG,
                    "Previous exit: reason=${exitReasonName(info.reason)}(${info.reason}) " +
                        "status=${info.status} importance=${info.importance} " +
                        "pss=${info.pss}kB rss=${info.rss}kB " +
                        "timestamp=${info.timestamp} description=${info.description}",
                )
                // Present only for ANRs and native crashes, and the single most
                // useful artifact when it is: the tombstone or ANR trace.
                runCatching {
                    info.traceInputStream?.use { stream ->
                        val trace = stream.bufferedReader().readText().take(MAX_EXIT_TRACE_CHARS)
                        if (trace.isNotBlank()) AppLogger.i(TAG, "Previous exit trace:\n$trace")
                    }
                }.onFailure { AppLogger.w(TAG, "Could not read previous exit trace", it) }
            }
        } catch (e: Throwable) {
            // Diagnostics must never be the reason startup fails.
            AppLogger.w(TAG, "Failed to read previous exit reasons", e)
        }
    }

    @RequiresApi(Build.VERSION_CODES.R)
    private fun exitReasonName(reason: Int): String = when (reason) {
        ApplicationExitInfo.REASON_ANR -> "ANR"
        ApplicationExitInfo.REASON_CRASH -> "CRASH"
        ApplicationExitInfo.REASON_CRASH_NATIVE -> "CRASH_NATIVE"
        ApplicationExitInfo.REASON_DEPENDENCY_DIED -> "DEPENDENCY_DIED"
        ApplicationExitInfo.REASON_EXCESSIVE_RESOURCE_USAGE -> "EXCESSIVE_RESOURCE_USAGE"
        ApplicationExitInfo.REASON_EXIT_SELF -> "EXIT_SELF"
        ApplicationExitInfo.REASON_INITIALIZATION_FAILURE -> "INITIALIZATION_FAILURE"
        ApplicationExitInfo.REASON_LOW_MEMORY -> "LOW_MEMORY"
        ApplicationExitInfo.REASON_OTHER -> "OTHER"
        ApplicationExitInfo.REASON_PERMISSION_CHANGE -> "PERMISSION_CHANGE"
        ApplicationExitInfo.REASON_SIGNALED -> "SIGNALED"
        ApplicationExitInfo.REASON_USER_REQUESTED -> "USER_REQUESTED"
        ApplicationExitInfo.REASON_USER_STOPPED -> "USER_STOPPED"
        else -> "UNKNOWN"
    }
}
