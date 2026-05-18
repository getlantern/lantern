package foundation.bridge

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import foundation.engine.libbox.Notification
import foundation.engine.libbox.StringIterator
import foundation.engine.libbox.TunOptions
import foundation.engine.mobile.Mobile
import foundation.engine.utils.FlutterEvent
import foundation.engine.utils.FlutterEventEmitter
import foundation.engine.utils.Opts
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

class NetworkService : VpnService(), foundation.engine.utils.PlatformInterface {
    companion object {
        private const val TAG = "NetworkService"
        const val ACTION_CONNECT = "foundation.bridge.CONNECT"
        const val ACTION_DISCONNECT = "foundation.bridge.DISCONNECT"
    }

    private val serviceScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var tunFd: ParcelFileDescriptor? = null
    private val eventEmitter = object : FlutterEventEmitter {
        override fun sendEvent(event: FlutterEvent?) {
        }
    }

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
            runCatching { Mobile.stopVPN() }
            closeTun()
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
        runCatching { Mobile.stopVPN() }
        closeTun()
        BridgeState.set("disconnected")
        BridgeNotification.clear(this@NetworkService)
        stopSelf()
    }

    private suspend fun startConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("connecting")
        if (!Mobile.isRadianceConnected()) {
            Mobile.startIPCServer(this@NetworkService, opts())
            Mobile.setupRadiance(opts(), eventEmitter)
        }
        Mobile.startVPN()
        BridgeState.set("connected")
        BridgeNotification.show(this@NetworkService, "Connected")
    }

    private suspend fun stopConnection() = withContext(Dispatchers.IO) {
        BridgeState.set("disconnecting")
        runCatching { Mobile.stopVPN() }
        closeTun()
        BridgeState.set("disconnected")
        BridgeNotification.clear(this@NetworkService)
        stopSelf()
    }

    override fun openTun(tunOptions: TunOptions): Int {
        val fd = Builder()
            .setSession(BuildConfig.SESSION_NAME)
            .setMtu(tunOptions.mtu)
            .apply {
                val inet4Address = tunOptions.inet4Address
                while (inet4Address.hasNext()) {
                    val address = inet4Address.next()
                    addAddress(address.address(), address.prefix())
                }
                val inet6Address = tunOptions.inet6Address
                while (inet6Address.hasNext()) {
                    val address = inet6Address.next()
                    addAddress(address.address(), address.prefix())
                }
                if (tunOptions.autoRoute) {
                    addDnsServer(tunOptions.dnsServerAddress.value)
                    addRoute("0.0.0.0", 0)
                    addRoute("::", 0)
                }
                addDisallowedApplication(BuildConfig.APPLICATION_ID)
            }
            .establish()
            ?: error("connection permission is not prepared")
        tunFd = fd
        return fd.fd
    }

    override fun autoDetectInterfaceControl(fd: Int) {
        protect(fd)
    }

    override fun postServiceClose() {
        closeTun()
    }

    override fun restartService() {
        runBlocking(Dispatchers.IO) {
            stopConnection()
            startConnection()
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
    }

    private fun opts(): Opts {
        return Opts().apply {
            dataDir = BridgePaths.dataDir(this@NetworkService)
            logDir = BridgePaths.logDir(this@NetworkService)
            logLevel = "warn"
            deviceid = BridgePaths.deviceId(this@NetworkService)
            locale = BridgePaths.locale()
            telemetryConsent = false
            env = ""
            platform = this@NetworkService
        }
    }

    @Synchronized
    private fun closeTun() {
        try {
            tunFd?.close()
        } finally {
            tunFd = null
        }
    }
}
