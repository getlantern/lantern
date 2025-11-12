package org.getlantern.lantern.handler

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
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
import org.getlantern.lantern.apps.AppFilters.SYSTEM_APPS_ALLOWLIST
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.utils.PrivateServerListener
import org.getlantern.lantern.utils.VpnStatusManager
import java.io.File
import java.io.FileOutputStream
import java.util.Locale
import org.json.JSONArray
import org.json.JSONObject


enum class Methods(val method: String) {
    Start("startVPN"),
    Stop("stopVPN"),
    ConnectToServer("connectToServer"),
    IsVpnConnected("isVPNConnected"),

    StripeSubscription("stripeSubscription"),
    StripeBillingPortal("stripeBillingPortal"),
    Plans("plans"),
    GetUserData("getUserData"),
    FetchUserData("fetchUserData"),
    AcknowledgeInAppPurchase("acknowledgeInAppPurchase"),
    PaymentRedirect("paymentRedirect"),
    ReportIssue("reportIssue"),
    FeatureFlag("featureFlag"),
    GetDataCapInfo("getDataCapInfo"),

    //Oauth
    OAuthLoginUrl("oauthLoginUrl"),
    OAuthLoginCallback("oauthLoginCallback"),

    //Forgot password
    StartRecoveryByEmail("startRecoveryByEmail"),
    ValidateRecoveryCode("validateRecoveryCode"),
    CompleteRecoveryByEmail("completeRecoveryByEmail"),

    //Login
    Login("login"),
    SignUp("signUp"),

    //Change Email
    StartChangeEmail("startChangeEmail"),
    CompleteChangeEmail("completeChangeEmail"),

    Logout("logout"),
    DeleteAccount("deleteAccount"),
    ActivationCode("activationCode"),

    //Device
    RemoveDevice("removeDevice"),
    AttachReferralCode("attachReferralCode"),

    //private server methods
    DigitalOcean("digitalOcean"),
    SelectAccount("selectAccount"),
    SelectProject("selectProject"),
    StartDeployment("startDeployment"),
    CancelDeployment("cancelDeployment"),
    SelectCertFingerprint("selectCertFingerprint"),
    AddServerManually("addServerManually"),
    InviteToServerManagerInstance("inviteToServerManagerInstance"),
    RevokeServerManagerInstance("revokeServerManagerInstance"),

    //custom/lantern servers
    GetLanternAvailableServers("getLanternAvailableServers"),
    GetAutoServerLocation("getAutoServerLocation"),

    //Split Tunnel methods
    SetSplitTunnelingEnabled("setSplitTunnelingEnabled"),
    IsSplitTunnelingEnabled("isSplitTunnelingEnabled"),
    AddSplitTunnelItem("addSplitTunnelItem"),
    RemoveSplitTunnelItem("removeSplitTunnelItem"),
    AddAllItems("addAllItems"),
    RemoveAllItems("removeAllItems"),
    InstalledApps("installedApps"),
    GetAppIcon("getAppIcon"),
}

class MethodHandler : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private lateinit var appContext: Context

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
    }

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val privateServerListener = PrivateServerListener()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
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

            Methods.ConnectToServer.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val location = map["location"] as String? ?: error("Missing location")
                        val tag = map["serverName"] as String? ?: error("Missing serverName")
                        MainActivity.instance.connectToServer(
                            location,
                            tag,
                        )
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
                    runCatching {
                        val connected = Mobile.isVPNConnected()

                        if (connected) {
                            VpnStatusManager.postVPNStatus(VPNStatus.Connected)
                        } else {
                            VpnStatusManager.postVPNStatus(VPNStatus.Disconnected)
                        }

                        withContext(Dispatchers.Main) {
                            result.success(connected)
                        }
                    }.onFailure { e ->
                        result.error("vpn_status", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.SetSplitTunnelingEnabled.method -> {
                scope.launch {
                    result.runCatching {
                        val enabled = call.argument<Boolean>("enabled") ?: error("Missing enabled")
                        Mobile.setSplitTunnelingEnabled(enabled)
                        withContext(Dispatchers.Main) { success("ok") }
                    }.onFailure { e ->
                        result.error("set_split_tunneling_enabled", e.localizedMessage ?: "Failed", e)
                    }
                }
            }

            Methods.IsSplitTunnelingEnabled.method -> {
                scope.launch {
                    runCatching {
                        val on = Mobile.isSplitTunnelingEnabled()
                        withContext(Dispatchers.Main) { result.success(on) }
                    }.onFailure { e ->
                        result.error("is_split_tunneling_enabled", e.localizedMessage ?: "Failed", e)
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

            Methods.AddAllItems.method -> {
                scope.launch {
                    result.runCatching {
                        val items = call.argument<String>("value")
                        Mobile.addSplitTunnelItems(items)
                        success("All items added")
                    }.onFailure { e ->
                        result.error(
                            "add_all_split_tunnel_items",
                            e.localizedMessage ?: "Failed to add all split tunnel items",
                            e
                        )
                    }
                }
            }

            Methods.RemoveAllItems.method -> {
                scope.launch {
                    result.runCatching {
                        val items = call.argument<String>("value")
                        Mobile.removeSplitTunnelItems(items)
                        success("All items removed")
                    }.onFailure { e ->
                        result.error(
                            "remove_all_split_tunnel_items",
                            e.localizedMessage ?: "Failed to remove all split tunnel items",
                            e
                        )
                    }
                }
            }

            Methods.InstalledApps.method -> {
                scope.launch {
                    result.runCatching {
                        val json = getLaunchableUserAppsJson(appContext)
                        withContext(Dispatchers.Main) { result.success(json) }
                    }.onFailure { e ->
                        result.error(
                            "installed_apps",
                            e.localizedMessage ?: "Failed to load apps",
                            e
                        )
                    }
                }
            }

            Methods.GetAppIcon.method -> {
                scope.launch {
                    result.runCatching {
                        val pkg = call.argument<String>("package") ?: error("Missing package")
                        val path = writeAppIconToCache(appContext, pkg)
                        withContext(Dispatchers.Main) { result.success(path) }
                    }.onFailure { e ->
                        result.error("get_app_icon", e.localizedMessage ?: "Failed to load icon", e)
                    }
                }
            }

            Methods.ReportIssue.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: ""
                        val issueType = map["issueType"] as String? ?: ""
                        val description = map["description"] as String? ?: ""
                        val device = map["device"] as String? ?: ""
                        val model = map["model"] as String? ?: ""
                        val logFilePath = map["logFilePath"] as String? ?: ""
                        Mobile.reportIssue(
                            email,
                            issueType,
                            description,
                            device,
                            model,
                            logFilePath
                        )
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "report_issue",
                            e.localizedMessage ?: "Failed to report issue",
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

            Methods.GetDataCapInfo.method -> {
                scope.launch {
                    result.runCatching {
                        val data = Mobile.getDataCapInfo()
                        val json = String(data, Charsets.UTF_8)
                        withContext(Dispatchers.Main) { success(json) }
                    }.onFailure { e ->
                        result.error("GetDataCapInfo", e.localizedMessage ?: "Please try again", e)
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

            Methods.CompleteRecoveryByEmail.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val code = call.argument<String>("code") ?: error("Missing code")
                        val newPassword =
                            map["newPassword"] as String? ?: error("Missing newPassword")
                        Mobile.completeRecoveryByEmail(email, newPassword, code)
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
                            "Login",
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
                            "SignUp",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.Logout.method -> {
                scope.launch {
                    result.runCatching {
                        val email = call.arguments<String>();
                        Log.d(TAG, "Logout email: $email")
                        val bytes = Mobile.logout(email)
                        withContext(Dispatchers.Main) {
                            success(bytes)
                        }
                    }.onFailure { e ->
                        result.error(
                            "Logout",
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
                            "DeleteAccount",
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
                            "ActivationCode",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.RemoveDevice.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val deviceId = map["deviceId"] as String? ?: error("Missing device ID")
                        Mobile.removeDevice(deviceId)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "RemoveDevice",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.AttachReferralCode.method -> {
                scope.launch {
                    result.runCatching {
                        val code = call.arguments as String
                        Mobile.referralAttachment(code)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "AttachReferralCode",
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
                    Mobile.startDeployment(location, serverName)
                }

            }

            Methods.CancelDeployment.method -> {
                scope.handleResult(
                    result,
                    "DigitalOcean"
                ) {
                    Mobile.cancelDeployment()
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

            Methods.InviteToServerManagerInstance.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val ip = map["ip"] as String? ?: error("Missing ip")
                        val port = map["port"] as String? ?: error("Missing port")
                        val accessToken =
                            map["accessToken"] as String? ?: error("Missing accessToken")
                        val inviteName = map["inviteName"] as String? ?: error("Missing inviteName")
                        val accessKey = Mobile.inviteToServerManagerInstance(
                            ip,
                            port,
                            accessToken,
                            inviteName
                        )
                        withContext(Dispatchers.Main) {
                            success(accessKey)
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

            Methods.RevokeServerManagerInstance.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val ip = map["ip"] as String? ?: error("Missing ip")
                        val port = map["port"] as String? ?: error("Missing port")
                        val accessToken =
                            map["accessToken"] as String? ?: error("Missing accessToken")
                        val inviteName = map["inviteName"] as String? ?: error("Missing inviteName")
                        Mobile.revokeServerManagerInvite(
                            ip,
                            port,
                            accessToken,
                            inviteName
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

            Methods.FeatureFlag.method -> {
                scope.launch {
                    result.runCatching {
                        val map = Mobile.availableFeatures()
                        withContext(Dispatchers.Main) {
                            success(String(map))
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
            //Change Email
            Methods.StartChangeEmail.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val newEmail = map["newEmail"] as String? ?: error("Missing newEmail")
                        val password = map["password"] as String? ?: error("Missing password")
                        Mobile.startChangeEmail(newEmail, password)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "StartChangeEmail",
                            e.localizedMessage ?: "Error while starting change email",
                            e
                        )
                    }
                }
            }

            Methods.CompleteChangeEmail.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val newEmail = map["newEmail"] as String? ?: error("Missing newEmail")
                        val password = map["password"] as String? ?: error("Missing password")
                        val code = map["code"] as String? ?: error("Missing code")
                        Mobile.completeChangeEmail(newEmail, password, code)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "StartChangeEmail",
                            e.localizedMessage ?: "Error while starting change email",
                            e
                        )
                    }
                }
            }

            Methods.GetLanternAvailableServers.method -> {
                scope.launch {
                    result.runCatching {
                        val data = Mobile.getAvailableServers()
                        withContext(Dispatchers.Main) {
                            success(String(data))
                        }
                    }.onFailure { e ->
                        result.error(
                            "GetAvailableServers",
                            e.localizedMessage ?: "Error while fetching available servers",
                            e
                        )
                    }
                }
            }

            Methods.GetAutoServerLocation.method -> {
                scope.launch {
                    result.runCatching {
                        val data = Mobile.getAutoLocation()
                        withContext(Dispatchers.Main) {
                            success(data)
                        }
                    }.onFailure { e ->
                        result.error(
                            "GetAutoServerLocation",
                            e.localizedMessage ?: "Error while fetching auto server location",
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

private data class AppEntry(val label: String, val packageName: String)

private fun getLaunchableUserAppsJson(ctx: Context): String {
    val pm = ctx.packageManager
    val intent = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)

    val resolveInfos = pm.queryIntentActivities(intent, PackageManager.MATCH_ALL)

    val ownPkg = ctx.packageName
    val entries = resolveInfos.mapNotNull { ri ->
        val pkg = ri.activityInfo?.packageName ?: return@mapNotNull null
        val label = try { ri.loadLabel(pm).toString() } catch (_: Exception) { pkg }

        // filter ourselves, and system apps except allowlisted ones
        if (pkg == ownPkg || (isSystemApp(pm, pkg) && pkg !in SYSTEM_APPS_ALLOWLIST)) {
            return@mapNotNull null
        }

        AppEntry(label, pkg)
    }
        .distinctBy { it.packageName }
        .sortedBy { it.label.lowercase(Locale.getDefault()) }

    val arr = JSONArray()
    entries.forEach { a ->
        arr.put(JSONObject().apply {
            put("name", a.label)
            put("bundleId", a.packageName)
            put("appPath", "")
            put("iconPath", "")
        })
    }
    return arr.toString()
}

private fun writeAppIconToCache(ctx: Context, packageName: String): String {
    val pm = ctx.packageManager
    val drawable = pm.getApplicationIcon(packageName)
    val bmp = drawableToBitmap(drawable)
    val file = File(ctx.cacheDir, "appicon_$packageName.png")
    FileOutputStream(file).use { out ->
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
    }
    return file.absolutePath
}

private fun drawableToBitmap(drawable: Drawable): Bitmap {
    if (drawable is BitmapDrawable && drawable.bitmap != null) return drawable.bitmap
    val w = drawable.intrinsicWidth.coerceAtLeast(1)
    val h = drawable.intrinsicHeight.coerceAtLeast(1)
    val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
    val canvas = android.graphics.Canvas(bmp)
    drawable.setBounds(0, 0, canvas.width, canvas.height)
    drawable.draw(canvas)
    return bmp
}

private fun isSystemApp(pm: PackageManager, packageName: String): Boolean {
    return try {
        val ai = pm.getApplicationInfo(packageName, 0)
        (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0 ||
        (ai.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0
    } catch (_: Exception) {
        false
    }
}