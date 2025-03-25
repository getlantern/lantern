package org.getlantern.lantern.handler

import androidx.lifecycle.Observer
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.utils.Event
import org.getlantern.lantern.utils.VpnStatusManager
import kotlin.Result.Companion.success


enum class Methods(val method: String) {
    Start("startVPN"), Stop("stopVPN"),
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
                    val observer = object : Observer<Event<Result<String>>> {
                        override fun onChanged(event: Event<Result<String>>) {
                            event.contentIfNotHandled?.let { status ->
                                status.onSuccess {
                                    success(it)
                                    VpnStatusManager.statusLiveData.removeObserver(this)
                                    result.success(it)
                                }.onFailure { e ->
                                    result.error(
                                        "start_vpn",
                                        e.localizedMessage ?: "Please try again",
                                        e
                                    )
                                    VpnStatusManager.statusLiveData.removeObserver(this)
                                }
                            }
                        }
                    }

                    result.runCatching {
                        MainActivity.instance.startVPN()
                        VpnStatusManager.statusLiveData.observe(MainActivity.instance, observer)
                    }.onFailure { e ->
                        result.error("start_vpn", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.Stop.method -> {
                scope.launch {
                    result.runCatching {
                        MainActivity.instance.stopVPN()
                        success("VPN stopped")
                    }.onFailure { e ->
                        result.error("stop_vpn", e.localizedMessage ?: "Please try again", e)
                    }

                }
            }

            else -> {
                result.notImplemented()
            }
        }

    }
}