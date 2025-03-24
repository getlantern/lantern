package org.getlantern.lantern.handler

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.getlantern.lantern.MainActivity


enum class Methods(val method: String) {
    Start("startVPN"),
    Stop("stopVPN"),
}

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
    }


    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Methods.Start.method -> {
                scope.launch {
                    result.runCatching {
                        MainActivity.instance.startVPN()
                        success(null)
                    }.onFailure { e ->
                        result.error("start_vpn", e.localizedMessage ?: "Please try again ", e)
                    }
                }
            }

            Methods.Stop.method -> {
                scope.launch {
                    result.success("stop")
                }
            }

            else -> {
                result.notImplemented()
            }
        }

    }
}