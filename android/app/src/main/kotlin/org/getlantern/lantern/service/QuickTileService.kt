package org.getlantern.lantern.service

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.VpnService
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import lantern.io.mobile.Mobile
import org.getlantern.lantern.LanternApp
import org.getlantern.lantern.service.LanternVpnService.Companion.ACTION_STOP_VPN
import org.getlantern.lantern.utils.isServiceRunning

@RequiresApi(24)
class QuickTileService : TileService() {

    companion object {
        private const val TAG = "QuickTileService"
        private const val ACTION_TILE_UPDATE = "org.getlantern.TILE_UPDATE"

        fun triggerUpdateTileState(context: Context, isVPNConnected: Boolean = false) {
            val intent = Intent(ACTION_TILE_UPDATE).setPackage(context.packageName)
            intent.putExtra("isVPNConnected", isVPNConnected)
            Log.d(TAG, "triggerUpdateTileState: $isVPNConnected")
            context.sendBroadcast(intent)
        }
    }

    private val tileScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val tileBroadcastReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.takeIf { it.action == ACTION_TILE_UPDATE }?.apply {
                val isConnected = getBooleanExtra("isVPNConnected", false)
                updateTileState(isConnected)
            }
        }
    }

    override fun onStartListening() {
        super.onStartListening()
        Log.d(TAG, "onStartListening")
        readState()
        registerTileReceiver()
    }

    override fun onStopListening() {
        super.onStopListening()
        unregisterReceiver(tileBroadcastReceiver)
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "onDestroy")
        tileScope.cancel()
    }

    override fun onClick() {
        Log.d(TAG, "onClick")
        when {
            Mobile.isRadianceConnected() -> handleVPNState()
            else -> {
                connectService(LanternVpnService.ACTION_START_RADIANCE)
                connectVPN()
            }
        }
    }

    private fun registerTileReceiver() {
        ContextCompat.registerReceiver(
            this, tileBroadcastReceiver, IntentFilter(ACTION_TILE_UPDATE),
            ContextCompat.RECEIVER_NOT_EXPORTED
        )
    }

    private fun readState() {
        try {
            val connected = Mobile.isRadianceConnected()
            val vpnConnected = Mobile.isVPNConnected()
            updateTileState(if (connected) vpnConnected else false)
        } catch (e: Exception) {
            Log.e(TAG, "Error reading state", e)
            updateTile(Tile.STATE_UNAVAILABLE)
        }

    }

    private fun handleVPNState() {
        if (Mobile.isVPNConnected()) stopVPN() else connectVPN()
    }

    private fun connectVPN() {
        isPermissionIntent()?.let { handleVpnPermissionRequest(it) }
            ?: ContextCompat.startForegroundService(
                this, Intent(this, LanternVpnService::class.java).apply {
                    action = LanternVpnService.ACTION_TILE_START
                }
            )
    }

    private fun connectService(action: String) {
        if (!isServiceRunning(this, LanternVpnService::class.java)) {
            runCatching {
                startService(Intent(this, LanternVpnService::class.java).apply {
                    this.action = action
                })
                Log.d(TAG, "$action service started")
            }.onFailure { Log.e(TAG, "Error starting service", it) }
        } else {
            Log.d(TAG, "$action service already running")
        }
    }

    private fun stopVPN() {
        LanternApp.application.sendBroadcast(
            Intent(ACTION_STOP_VPN).setPackage(LanternApp.application.packageName)
        )
        Log.d(TAG, "VPN service stopped")
    }

    private fun isPermissionIntent(): Intent? = VpnService.prepare(this)

    private fun handleVpnPermissionRequest(intent: Intent) {
        runCatching {
            PendingIntent.getActivity(
                this, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ).send()
        }.onFailure { Log.e(TAG, "Failed to send VPN permission intent", it) }
    }

    private fun updateTileState(isVPNConnected: Boolean) {
        Log.d(TAG, "updateTileState")
        tileScope.launch {
            delay(500)
            updateTile(if (isVPNConnected) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE)
        }
    }

    private fun updateTile(state: Int) {
        qsTile?.apply {
            this.state = state
            label = if (state == Tile.STATE_ACTIVE) "VPN Connected" else "VPN Disconnected"
            updateTile()
            Log.d(
                TAG,
                "Tile state updated: ${if (state == Tile.STATE_ACTIVE) "Connected" else "Disconnected"}"
            )
        }
    }
}

