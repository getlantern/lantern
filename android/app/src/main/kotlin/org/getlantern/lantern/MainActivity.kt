package org.getlantern.lantern

import android.content.Intent
import android.net.VpnService
import android.util.Log
import androidx.lifecycle.lifecycleScope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.handler.EventHandler
import org.getlantern.lantern.handler.MethodHandler
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN
import org.getlantern.lantern.utils.VpnStatusManager
import org.getlantern.lantern.utils.isServiceRunning


class MainActivity : FlutterActivity() {
    companion object {
        const val TAG = "A/MainActivity"
        lateinit var instance: MainActivity
        const val VPN_PERMISSION_REQUEST_CODE = 7777
        var receiverRegistered: Boolean = false
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        instance = this
        Log.d(TAG, "Configuring FlutterEngine")
        ///Setup handler
        flutterEngine.plugins.add(MethodHandler(lifecycleScope))
        flutterEngine.plugins.add(EventHandler())
        startService()
    }

    private fun startService() {
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
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun startVPN() {
        if (!isVPNServiceReady()) {
            Log.d(TAG, "VPN service not ready")
            return
        }
        try {
            val vpnIntent = Intent(this, LanternVpnService::class.java).apply {
                action = LanternVpnService.ACTION_START_VPN
            }
            startService(vpnIntent)
            Log.d(TAG, "VPN service started")
        } catch (e: Exception) {
            e.printStackTrace()
            Log.e(TAG, "Error starting VPN service", e)
            throw e
        }
    }

    fun stopVPN() {
        LanternApp.application.sendBroadcast(
            Intent(ACTION_STOP_VPN).setPackage(
                LanternApp.application.packageName
            )
        )
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


}
