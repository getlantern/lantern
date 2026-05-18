package foundation.bridge

import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import foundation.engine.mobile.Mobile
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class SyncService : Service() {
    companion object {
        private const val TAG = "SyncService"
        const val ACTION_CONNECT = "foundation.bridge.CONNECT"
        const val ACTION_DISCONNECT = "foundation.bridge.DISCONNECT"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return when (intent?.action) {
            ACTION_DISCONNECT -> {
                launchServiceWork { stopConnection() }
                START_NOT_STICKY
            }
            else -> {
                BridgeNotification.show(this, "Connecting")
                launchServiceWork { startConnection() }
                START_STICKY
            }
        }
    }

    override fun onDestroy() {
        runBlocking(Dispatchers.IO) {
            runCatching { Mobile.stopProxy() }
        }
        serviceScope.cancel()
        super.onDestroy()
    }

    private fun launchServiceWork(block: suspend () -> Unit) {
        serviceScope.launch {
            try {
                block()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (exception: Exception) {
                Log.e(TAG, "Failed service operation", exception)
                failConnection()
            }
        }
    }

    private suspend fun failConnection() = withContext(Dispatchers.IO) {
        runCatching { Mobile.stopProxy() }
        BridgeState.set("disconnected")
        BridgeNotification.clear(this@SyncService)
        stopSelf()
    }

    private suspend fun startConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("connecting")
        Mobile.startProxy(
            BridgePaths.dataDir(this@SyncService),
            BridgePaths.logDir(this@SyncService),
            BridgePaths.deviceId(this@SyncService),
            BridgePaths.locale(),
            false,
            BuildConfig.LOCAL_PROXY_HOST,
            BuildConfig.LOCAL_PROXY_PORT.toLong(),
        )
        BridgeState.set("connected")
        BridgeNotification.show(this@SyncService, "Connected")
    }

    private suspend fun stopConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("disconnecting")
        runCatching { Mobile.stopProxy() }
        BridgeState.set("disconnected")
        BridgeNotification.clear(this@SyncService)
        stopSelf()
    }
}
