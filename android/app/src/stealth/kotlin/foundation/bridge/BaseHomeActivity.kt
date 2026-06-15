package foundation.bridge

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.MainScope
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

abstract class BaseHomeActivity : FlutterActivity() {
    private val scope = MainScope()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BridgeContext.application = application
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "foundation.bridge/control",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "connect" -> scope.launch {
                    runCatching { connect() }
                        .onSuccess { result.success(null) }
                        .onFailure { result.error("connect_failed", it.message, null) }
                }
                "disconnect" -> scope.launch {
                    runCatching { disconnect() }
                        .onSuccess { result.success(null) }
                        .onFailure { result.error("disconnect_failed", it.message, null) }
                }
                "state" -> result.success(BridgeState.get())
                "error" -> result.success(BridgeState.getError())
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }

    protected fun startAction(service: Class<*>, action: String) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(Intent(this, service).setAction(action))
        } else {
            startService(Intent(this, service).setAction(action))
        }
    }

    protected abstract suspend fun connect()

    protected abstract suspend fun disconnect()
}
