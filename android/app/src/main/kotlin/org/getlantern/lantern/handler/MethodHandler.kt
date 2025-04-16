package org.getlantern.lantern.handler

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import lantern.io.mobile.Mobile
import org.getlantern.lantern.MainActivity
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.VpnStatusManager


enum class Methods(val method: String) {
    Start("startVPN"),
    Stop("stopVPN"),
    IsVpnConnected("isVPNConnected"),
    SubscriptionPaymentRedirect("subscriptionPaymentRedirect")
}

class MethodHandler : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())


    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            binding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Methods.Start.method -> {
                scope.launch {
                    result.runCatching {
                        VpnStatusManager.postVPNStatus(VPNStatus.Connecting)
                        MainActivity.instance.startVPN()
                        success("VPN started")
                    }.onFailure { e ->
                        VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
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

            Methods.IsVpnConnected.method -> {
                scope.launch {
                    result.runCatching {
                        val conncted = Mobile.isVPNConnected()
                        Log.d(TAG, "IsVpnConnected connected: $conncted")
                        if (conncted) {
                            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
                        } else {
                            VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                        }
                        success("")

                    }.onFailure { e ->
                        result.error("vpn_status", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.SubscriptionPaymentRedirect.method -> {
                scope.launch {
                    result.runCatching {
                        val subscriptionLink = Mobile.SubscripationPaymentRedirect()
                        withContext(Dispatchers.Main) {
                            success(subscriptionLink)
                        }
                    }.onFailure { e ->
                        result.error("vpn_status", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }

    }
}