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
    AddSplitTunnelItem("addSplitTunnelItem"),
    RemoveSplitTunnelItem("removeSplitTunnelItem"),
    StripeSubscription("stripeSubscription"),
    StripeBillingPortal("stripeBillingPortal"),
    Plans("plans"),
    OAuthLoginUrl("oauthLoginUrl"),
    OAuthLoginCallback("oauthLoginCallback"),
    GetUserData("getUserData"),
    FetchUserData("fetchUserData")
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

            Methods.AddSplitTunnelItem.method -> {
                scope.launch {
                    result.runCatching {
                        val filterType =
                            call.argument<String>("filterType") ?: error("Missing filterType")
                        val value = call.argument<String>("value") ?: error("Missing value")
                        Mobile.addSplitTunnelItem(filterType, value)
                        success("Item added")
                    }.onFailure { e ->
                        result.error(
                            "add_split_tunnel_item",
                            e.localizedMessage ?: "Failed to add split tunnel item",
                            e
                        )
                    }
                }
            }

            Methods.RemoveSplitTunnelItem.method -> {
                scope.launch {
                    result.runCatching {
                        val filterType =
                            call.argument<String>("filterType") ?: error("Missing filterType")
                        val value = call.argument<String>("value") ?: error("Missing value")
                        Mobile.removeSplitTunnelItem(filterType, value)
                        success("Item removed")
                    }.onFailure { e ->
                        result.error(
                            "remove_split_tunnel_item",
                            e.localizedMessage ?: "Failed to remove split tunnel item",
                            e
                        )
                    }
                }
            }

            Methods.StripeBillingPortal.method -> {
                scope.launch {
                    result.runCatching {
                        val url = Mobile.stripeBilingPortalUrl()
                        withContext(Dispatchers.Main) {
                            success(url)
                        }
                    }.onFailure { e ->
                        result.error("vpn_status", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.StripeSubscription.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val subscriptionData = Mobile.stripeSubscription(
                            map["email"] as String,
                            map["planId"] as String
                        )
                        withContext(Dispatchers.Main) {
                            success(subscriptionData)
                        }
                    }.onFailure { e ->
                        result.error(
                            "stripe_subscription",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.Plans.method -> {
                scope.launch {
                    result.runCatching {
                        val plansData = Mobile.plans()
                        withContext(Dispatchers.Main) {
                            success(plansData)
                        }
                    }.onFailure { e ->
                        result.error("plans", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.OAuthLoginUrl.method -> {
                scope.launch {
                    result.runCatching {
                        val provider = call.arguments<String>()
                        val loginUrl = Mobile.oAuthLoginUrl(provider)
                        withContext(Dispatchers.Main) {
                            success(loginUrl)
                        }
                    }.onFailure { e ->
                        result.error("OAuthLoginUrl", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.OAuthLoginCallback.method -> {
                scope.launch {
                    result.runCatching {
                        val token = call.arguments<String>()
                        val bytes = Mobile.oAuthLoginCallback(token)
                        withContext(Dispatchers.Main) {
                            success(bytes)
                        }
                    }.onFailure { e ->
                        result.error(
                            "OAuthLoginCallback",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.GetUserData.method -> {
                scope.launch {
                    result.runCatching {
                        val bytes = Mobile.userData()
                        withContext(Dispatchers.Main) {
                            success(bytes)
                        }
                    }.onFailure { e ->
                        result.error(
                            "OAuthLoginCallback",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.FetchUserData.method -> {
                scope.launch {
                    result.runCatching {
                        val bytes = Mobile.fetchUserData()
                        withContext(Dispatchers.Main) {
                            success(bytes)
                        }
                    }.onFailure { e ->
                        result.error(
                            "OAuthLoginCallback",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            else -> {
                result.notImplemented()
            }
        }

    }
}