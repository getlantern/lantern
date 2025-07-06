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
import org.getlantern.lantern.utils.PrivateServerListener
import org.getlantern.lantern.utils.VpnStatusManager


enum class Methods(val method: String) {
    Start("startVPN"),
    Stop("stopVPN"),
    SetPrivateServer("setPrivateServer"),
    IsVpnConnected("isVPNConnected"),
    AddSplitTunnelItem("addSplitTunnelItem"),
    RemoveSplitTunnelItem("removeSplitTunnelItem"),
    StripeSubscription("stripeSubscription"),
    StripeBillingPortal("stripeBillingPortal"),
    Plans("plans"),
    GetUserData("getUserData"),
    FetchUserData("fetchUserData"),
    AcknowledgeInAppPurchase("acknowledgeInAppPurchase"),
    PaymentRedirect("paymentRedirect"),

    //Oauth
    OAuthLoginUrl("oauthLoginUrl"),
    OAuthLoginCallback("oauthLoginCallback"),

    //Forgot password
    StartRecoveryByEmail("startRecoveryByEmail"),
    ValidateRecoveryCode("validateRecoveryCode"),
    CompleteChangeEmail("completeChangeEmail"),

    //Login
    Login("login"),
    SignUp("signUp"),

    Logout("logout"),
    DeleteAccount("deleteAccount"),
    ActivationCode("activationCode"),

    //private server methods
    DigitalOcean("digitalOcean"),
    SelectAccount("selectAccount"),
    SelectProject("selectProject"),
    StartDeployment("startDeployment"),
    CancelDeployment("cancelDeployment"),
    SelectCertFingerprint("selectCertFingerprint"),
    AddServerManually("addServerManually"),

}

class MethodHandler : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val privateServerListener = PrivateServerListener()

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

            Methods.SetPrivateServer.method -> {
                scope.launch {
                    result.runCatching {
                        Mobile.setPrivateServer(call.arguments as String)
                        success("ok")
                    }.onFailure { e ->
                        result.error(
                            "set_private_server",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
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
                        val url = Mobile.stripeBillingPortalUrl()
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

            Methods.AcknowledgeInAppPurchase.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val subscriptionData = Mobile.acknowledgeGooglePurchase(
                            map["purchaseToken"] as String,
                            map["planId"] as String
                        )
                        withContext(Dispatchers.Main) {
                            success("success")
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

            Methods.PaymentRedirect.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val url = Mobile.paymentRedirect(
                            map["provider"] as String,
                            map["planId"] as String,
                            map["email"] as String
                        )
                        withContext(Dispatchers.Main) {
                            success(url)
                        }
                    }.onFailure { e ->
                        result.error(
                            "payment_redirect",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.Plans.method -> {
                scope.launch {
                    result.runCatching {
                        val plansData = Mobile.plans(call.arguments<String>())
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
            ///User management methods

            Methods.StartRecoveryByEmail.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        Mobile.startRecoveryByEmail(email)
                        withContext(Dispatchers.Main) {
                            success("recovery mail sent")
                        }
                    }.onFailure { e ->
                        result.error(
                            "StartRecoveryByEmail",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.ValidateRecoveryCode.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val code = call.argument<String>("code") ?: error("Missing code")
                        Mobile.validateChangeEmailCode(email, code)
                        withContext(Dispatchers.Main) {
                            success("recovery code validated")
                        }
                    }.onFailure { e ->
                        result.error(
                            "ValidateRecoveryCode",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.CompleteChangeEmail.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val code = call.argument<String>("code") ?: error("Missing code")
                        val newPassword =
                            map["newPassword"] as String? ?: error("Missing newPassword")
                        Mobile.completeChangeEmail(email, newPassword, code)
                        withContext(Dispatchers.Main) {
                            success("email changed successfully")
                        }
                    }.onFailure { e ->
                        result.error(
                            "CompleteChangeEmail",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.Login.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val password = map["password"] as String? ?: error("Missing password")
                        val bytes = Mobile.login(email, password)
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

            Methods.SignUp.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val password = map["password"] as String? ?: error("Missing password")
                        Mobile.signUp(email, password)
                        withContext(Dispatchers.Main) {
                            success("ok")
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

            Methods.Logout.method -> {
                scope.launch {
                    result.runCatching {
                        val bytes = Mobile.logout(call.arguments<String>() as String)
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

            Methods.DeleteAccount.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val password = map["password"] as String? ?: error("Missing password")
                        val bytes = Mobile.deleteAccount(email, password)
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

            Methods.ActivationCode.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val resellerCode =
                            map["resellerCode"] as String? ?: error("Missing resellerCode")
                        Mobile.activationCode(email, resellerCode)
                        withContext(Dispatchers.Main) {
                            success("ok")
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

            //Private server methods
            Methods.DigitalOcean.method -> {
                scope.handleResult(
                    result,
                    "DigitalOcean"
                ) {
                    Mobile.digitalOceanPrivateServer(privateServerListener)
                }
            }

            Methods.SelectAccount.method -> {
                scope.handleResult(
                    result,
                    "SelectAccount"
                ) {
                    val userInput = call.arguments<String>()
                    Mobile.selectAccount(userInput)
                }

            }

            Methods.SelectProject.method -> {
                scope.handleResult(
                    result,
                    "SelectProject"
                ) {
                    // This method is called when the user selects a project from the list
                    // The project name is passed as an argument
                    val userInput = call.arguments<String>()
                    Mobile.selectProject(userInput)
                }

            }

            Methods.StartDeployment.method -> {
                scope.handleResult(
                    result,
                    "StartDeployment"
                ) {
                    val map = call.arguments as Map<*, *>
                    val location = map["location"] as String? ?: error("Missing location")
                    val serverName = map["serverName"] as String? ?: error("Missing serverName")
                    Mobile.startDepolyment(location, serverName)
                }

            }

            Methods.CancelDeployment.method -> {
                scope.handleResult(
                    result,
                    "DigitalOcean"
                ) {
                    Mobile.cancelDepolyment()
                }

            }

            Methods.SelectCertFingerprint.method -> {
                scope.handleResult(
                    result,
                    "SelectCertFingerprint"
                ) {
                    Mobile.selectedCertFingerprint(call.arguments as String)
                }

            }

            Methods.AddServerManually.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val ip = map["ip"] as String? ?: error("Missing ip")
                        val port = map["port"] as String? ?: error("Missing port")
                        val accessToken =
                            map["accessToken"] as String? ?: error("Missing accessToken")
                        val serverName = map["serverName"] as String? ?: error("Missing serverName")
                        Mobile.addServerManagerInstance(
                            ip,
                            port,
                            accessToken,
                            serverName,
                            privateServerListener
                        )
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "DigitalOcean",
                            e.localizedMessage ?: "Error while activating Digital Ocean",
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

inline fun CoroutineScope.handleResult(
    result: MethodChannel.Result,
    errorTitle: String = "DigitalOcean",
    crossinline block: suspend () -> Unit
) {
    this.launch {
        runCatching {
            block()
            withContext(Dispatchers.Main) {
                result.success("ok")
            }
        }.onFailure { e ->
            result.error(
                errorTitle,
                e.localizedMessage ?: "Unknown error",
                e
            )
        }
    }
}
