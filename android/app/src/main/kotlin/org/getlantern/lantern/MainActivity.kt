package org.getlantern.lantern

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
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
import org.getlantern.lantern.notification.NotificationHelper
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.QuickTileService
import org.getlantern.lantern.utils.DeviceUtil
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.isServiceRunning
import org.getlantern.lantern.utils.setupDirs


class MainActivity : FlutterFragmentActivity() {
    companion object {
        const val TAG = "A/MainActivity"
        lateinit var instance: MainActivity
        const val VPN_PERMISSION_REQUEST_CODE = 7777
        const val NOTIFICATION_PERMISSION_REQUEST_CODE = 1010
        var receiverRegistered: Boolean = false
        var pendingServiceStart: Boolean = false
    }

    private var retryCount = 0
    private val maxRetries = 5
    private val RETRY_DELAY_MS = 2000L // 2 seconds

    private val serviceStartHandler = Handler(Looper.getMainLooper())


    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        instance = this
        Log.d(TAG, "Configuring FlutterEngine ${DeviceUtil.deviceId()}")
        setupDirs()
        Log.d(TAG, "Config directories set up")
        ///Setup handler
        flutterEngine.plugins.add(EventHandler())
        flutterEngine.plugins.add(MethodHandler())
        startLanternService()
    }

    override fun onResume() {
        super.onResume()
        // Check if there is a pending service start
        if (pendingServiceStart) {
            Log.d(TAG, "Retrying pending service start")
            startLanternService()
        }
    }

    private fun startLanternService() {
        Log.d(TAG, "Starting LanternService")
        if (isServiceRunning(this, LanternVpnService::class.java)) {
            Log.d(TAG, "LanternService is already running")
            return
        }
        try {
            val radianceIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_START_RADIANCE
            }
            startService(radianceIntent)
            Log.d(TAG, "LanternService started")
            pendingServiceStart = false
        } catch (e: IllegalStateException) {
            Log.e(TAG, "Cannot start service in background: ${e.message}")
            // App is in background, schedule for when app comes to foreground
            pendingServiceStart = true
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e(TAG, "Error starting LanternService", e)
            // Got some issue starting service, schedule immediate retry
            handleImmediateRetry()
        }
    }

    private fun handleImmediateRetry() {
        Log.d(TAG, "Handling immediate retry for LanternService start")
        if (retryCount < maxRetries) {
            retryCount++
            val delay = RETRY_DELAY_MS * retryCount // Exponential backoff

            Log.d(TAG, "Scheduling immediate retry #$retryCount in ${delay}ms")
            serviceStartHandler.postDelayed({
                startLanternService()
            }, delay)
        } else {
            Log.e(TAG, "Max retries ($maxRetries) reached. Service start failed.")
            // Optionally notify user or handle failure
            // Wait for app to come to foreground
            pendingServiceStart = true
        }
    }


    fun startVPN() {
        if (!NotificationHelper.hasPermission()) {
            askNotificationPermission()
            return
        }
        if (!isVPNServiceReady()) {
            Log.d(TAG, "VPN service not ready")
            return
        }

        try {
            val vpnIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_START_VPN
            }
            ContextCompat.startForegroundService(this, vpnIntent)
            Log.d(TAG, "VPN service started")
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e(TAG, "Error starting VPN service", e)
            throw e
        }
    }

    fun connectToServer(location: String, tag: String) {
        if (!NotificationHelper.hasPermission()) {
            askNotificationPermission()
            return
        }
        if (!isVPNServiceReady()) {
            Log.d(TAG, "VPN service not ready")
            return
        }
        // Check if VPN is already connected
        // if so then user already have vpn on now wish to switch server
        // Do not need to create server again just switch server
        if (Mobile.isVPNConnected()) {
            Log.d(TAG, "VPN is already connected, switching server")
            CoroutineScope(Dispatchers.Main).launch {
                LanternVpnService.instance.connectToServer(location, tag)
            }
            return
        }

        try {
            val vpnIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_CONNECT_TO_SERVER
                putExtra("tag", tag)
                putExtra("location", location)
            }
            ContextCompat.startForegroundService(this, vpnIntent)
            Log.d(TAG, "VPN service started")
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e(TAG, "Error starting VPN service", e)
            throw e
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
                Log.e(TAG, "stopVPN failed", e)
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
            Log.e(TAG, "Error preparing VPN service", e)
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
                startVPN()
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
                startVPN()
            } else {
                VpnStatusManager.postVPNStatus(VPNStatus.MissingPermission)
            }
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }


}
