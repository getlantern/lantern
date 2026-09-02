package org.getlantern.lantern.handler

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
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
import org.getlantern.lantern.apps.AppFilters
import org.getlantern.lantern.constant.VPNStatus
import org.getlantern.lantern.service.LanternVpnService
import org.getlantern.lantern.updater.AndroidSideloadInstaller
import org.getlantern.lantern.updater.AndroidSideloadUpdateRequest
import org.getlantern.lantern.utils.AppLogger
import org.getlantern.lantern.utils.PrivateServerListener
import org.getlantern.lantern.utils.VpnStatusManager
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.util.Locale


enum class Methods(val method: String) {

    ///VPN methods
    Start("startVPN"),
    Stop("stopVPN"),
    ConnectToServer("connectToServer"),
    IsVpnConnected("isVPNConnected"),
    IsTagAvailable("isTagAvailable"),

    //Payment methods
    StripeSubscription("stripeSubscription"),
    StripeBillingPortal("stripeBillingPortal"),
    Plans("plans"),
    AcknowledgeInAppPurchase("acknowledgeInAppPurchase"),
    RestoreInAppPurchase("restoreInAppPurchase"),
    PaymentRedirect("paymentRedirect"),
    LaunchExternalUrl("launchExternalUrl"),
    ReportIssue("reportIssue"),

    //Oauth
    OAuthLoginUrl("oauthLoginUrl"),
    OAuthLoginCallback("oauthLoginCallback"),

    //Forgot password
    StartRecoveryByEmail("startRecoveryByEmail"),
    ValidateRecoveryCode("validateRecoveryCode"),
    CompleteRecoveryByEmail("completeRecoveryByEmail"),

    //User data
    GetUserData("getUserData"),
    FetchUserData("fetchUserData"),
    WaitForRadiance("waitForRadiance"),

    //Login
    Login("login"),
    SignUp("signUp"),

    //Change Email
    VerifyPassword("verifyPassword"),
    StartChangeEmail("startChangeEmail"),
    CompleteChangeEmail("completeChangeEmail"),

    Logout("logout"),
    DeleteAccount("deleteAccount"),
    ActivationCode("activationCode"),

    //Device
    RemoveDevice("removeDevice"),
    AttachReferralCode("attachReferralCode"),
    AttachReferralCodeV2("attachReferralCodeV2"),

    // Ad blocking
    IsBlockAdsEnabled("isBlockAdsEnabled"),
    SetBlockAdsEnabled("setBlockAdsEnabled"),

    //private server methods
    DigitalOcean("digitalOcean"),
    SelectAccount("selectAccount"),
    SelectProject("selectProject"),
    StartDeployment("startDeployment"),
    CancelDeployment("cancelDeployment"),

    ValidateSession("validateSession"),
    AddServerManually("addServerManually"),
    InviteToServerManagerInstance("inviteToServerManagerInstance"),
    RevokeServerManagerInstance("revokeServerManagerInstance"),
    AddServerBasedOnURLs("addServerBasedOnURLs"),
    DeletePrivateServerByName("deletePrivateServerByName"),
    UpdatePrivateServerName("updatePrivateServerName"),

    //custom/lantern servers
    GetLanternAvailableServers("getLanternAvailableServers"),
    GetAutoServerLocation("getAutoServerLocation"),
    GetSelectedServerJSON("getSelectedServerJSON"),

    //Split Tunnel methods
    SetSplitTunnelingEnabled("setSplitTunnelingEnabled"),
    IsSplitTunnelingEnabled("isSplitTunnelingEnabled"),
    AddSplitTunnelItem("addSplitTunnelItem"),
    RemoveSplitTunnelItem("removeSplitTunnelItem"),
    AddAllItems("addAllItems"),
    RemoveAllItems("removeAllItems"),
    GetSplitTunnelItems("getSplitTunnelItems"),
    GetSplitTunnelState("getSplitTunnelState"),
    InstalledApps("installedApps"),
    GetAppIcon("getAppIcon"),

    //App Methods
    FeatureFlag("featureFlag"),
    GetDataCapInfo("getDataCapInfo"),
    UpdateLocale("updateLocale"),
    UpdateTelemetryEvents("updateTelemetryEvents"),
    InstallSideloadUpdate("installSideloadUpdate"),

    // Smart routing
    SetRoutingMode("setRoutingMode"),
    IsSmartRoutingEnabled("isSmartRoutingEnabled"),

    // Share My Connection (samizdat) + Unbounded (broflake) peer-share
    SetPeerProxyEnabled("setPeerProxyEnabled"),
    IsPeerProxyEnabled("isPeerProxyEnabled"),
    SetPeerManualPort("setPeerManualPort"),
    GetPeerManualPort("getPeerManualPort"),
    GetPeerStatus("getPeerStatus"),
    SetUnboundedEnabled("setUnboundedEnabled"),
    IsUnboundedEnabled("isUnboundedEnabled"),
    ProbeUPnP("probeUPnP"),

    // Telemetry
    IsTelemetryEnabled("isTelemetryEnabled"),

    // OAuth
    IsOAuthLogin("isOAuthLogin"),
    GetOAuthProvider("getOAuthProvider"),

    // VPN conflict detection
    CheckVpnConflict("checkVpnConflict"),

    // Developer mode
    PatchSettings("patchSettings"),
    GetSettings("getSettings"),
    PatchEnvVars("patchEnvVars"),
    GetEnvVars("getEnvVars"),
    RunURLTests("runURLTests"),
    SendConfigRequest("sendConfigRequest"),
    ClearTunnelCache("clearTunnelCache"),
}

class MethodHandler : FlutterPlugin,
    MethodChannel.MethodCallHandler {

    private var channel: MethodChannel? = null
    private lateinit var appContext: Context

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "org.getlantern.lantern/method"
        private const val MAX_EXTERNAL_URL_FALLBACK_DEPTH = 3
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
                        val tag = map["serverName"] as String? ?: error("Missing serverName")
                        MainActivity.instance.connectToServer(tag)
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

            Methods.IsTagAvailable.method -> {
                scope.launch {
                    try {
                        val tag = call.arguments as? String
                            ?: throw IllegalArgumentException("Missing or invalid tag")
                        val available = Mobile.isTagAvailable(tag)
                        withContext(Dispatchers.Main) {
                            result.success(available)
                        }
                    } catch (e: Throwable) {
                        withContext(Dispatchers.Main) {
                            result.error("tag_check_failed", e.localizedMessage ?: "Error", e)
                        }
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
                        result.error(
                            "set_split_tunneling_enabled",
                            e.localizedMessage ?: "Failed",
                            e
                        )
                    }
                }
            }

            Methods.IsSplitTunnelingEnabled.method -> {
                scope.launch {
                    runCatching {
                        val on = Mobile.isSplitTunnelingEnabled()
                        withContext(Dispatchers.Main) { result.success(on) }
                    }.onFailure { e ->
                        result.error(
                            "is_split_tunneling_enabled",
                            e.localizedMessage ?: "Failed",
                            e
                        )
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
                        val attachmentsJson = reportIssueAttachmentsJson(map["attachments"])
                        Mobile.reportIssue(
                            email,
                            issueType,
                            description,
                            device,
                            model,
                            logFilePath,
                            attachmentsJson
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
                            map["planId"] as String,
                            map["couponCode"] as? String ?: ""
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
                            map["planId"] as String,
                            map["couponCode"] as? String ?: ""
                        )
                        withContext(Dispatchers.Main) {
                            success(subscriptionData.toByteArray(Charsets.UTF_8))
                        }
                    }.onFailure { e ->
                        result.error(
                            "acknowledge_in_app_purchase",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            Methods.RestoreInAppPurchase.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val restoreData = Mobile.restoreGooglePlayPurchase(
                            map["purchaseToken"] as String,
                        )
                        withContext(Dispatchers.Main) {
                            success(restoreData.toByteArray(Charsets.UTF_8))
                        }
                    }.onFailure { e ->
                        result.error(
                            "restore_in_app_purchase",
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
                        val idempotencyKey = map["idempotencyKey"] as? String
                        if (idempotencyKey.isNullOrBlank()) {
                            throw IllegalArgumentException("Payment redirect idempotency key is required")
                        }
                        val url = Mobile.paymentRedirect(
                            map["provider"] as String,
                            map["planId"] as String,
                            map["email"] as String,
                            idempotencyKey,
                            map["couponCode"] as? String ?: ""
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

            Methods.LaunchExternalUrl.method -> {
                scope.handleValue(result, "launch_external_url") {
                    val url = call.arguments<String>()
                    if (url.isNullOrBlank()) {
                        throw IllegalArgumentException("External URL is required")
                    }
                    withContext(Dispatchers.Main) {
                        launchExternalUrl(url)
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
                        val json = Mobile.oAuthLoginCallback(token)
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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
                        val json = Mobile.userData()
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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

            Methods.WaitForRadiance.method -> {
                scope.handleValue<Any?>(result, "wait_for_radiance") {
                    LanternVpnService.awaitRadianceReady()
                    null
                }
            }

            Methods.FetchUserData.method -> {
                scope.launch {
                    result.runCatching {
                        val json = Mobile.fetchUserData()
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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
                        withContext(Dispatchers.Main) { success(data) }
                    }.onFailure { e ->
                        result.error("GetDataCapInfo", e.localizedMessage ?: "Please try again", e)
                    }
                }
            }

            Methods.UpdateLocale.method -> {
                scope.handleResult(result, "UpdateLocale") {
                    val locale = call.arguments<String>()
                    Mobile.updateLocale(locale)
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
                        val json = Mobile.login(email, password)
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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
                        AppLogger.d(TAG, "Logout email: $email")
                        val json = Mobile.logout(email)
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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
                        val json = Mobile.deleteAccount(email, password)
                        withContext(Dispatchers.Main) {
                            success(json.toByteArray(Charsets.UTF_8))
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

            Methods.AttachReferralCodeV2.method -> {
                scope.launch {
                    result.runCatching {
                        val code = call.argument<String>("code") ?: error("Missing code")
                        val distributionChannel =
                            call.argument<String>("distributionChannel") ?: ""
                        val response =
                            Mobile.referralAttachmentV2(code, distributionChannel)
                        withContext(Dispatchers.Main) {
                            success(response)
                        }
                    }.onFailure { e ->
                        result.error(
                            "AttachReferralCodeV2",
                            e.localizedMessage ?: "Please try again",
                            e
                        )
                    }
                }
            }

            // Ad blocking
            Methods.SetBlockAdsEnabled.method -> {
                scope.handleResult(result, "set_block_ads_enabled") {
                    val enabled = call.argument<Boolean>("enabled") ?: error("Missing enabled")
                    Mobile.setBlockAdsEnabled(enabled)
                }
            }

            Methods.IsBlockAdsEnabled.method -> {
                scope.handleValue(result, "is_block_ads_enabled") {
                    Mobile.isBlockAdsEnabled()
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

            Methods.ValidateSession.method -> {
                scope.handleResult(
                    result,
                    "ValidateSession"
                ) {
                    Mobile.validateSession()
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

            Methods.AddServerBasedOnURLs.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val urls = map["urls"] as String? ?: error("Missing urls")
                        val skipValidation =
                            map["skipValidation"] as Boolean? ?: error("Missing skipValidation")

                        val tags = Mobile.addServerBasedOnURLs(
                            urls,
                            skipValidation,
                        )
                        withContext(Dispatchers.Main) {
                            success(tags)
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

            Methods.DeletePrivateServerByName.method -> {
                scope.launch {
                    result.runCatching {
                        val name = call.arguments as String? ?: error("Missing serverName")
                        Mobile.deletePrivateServerByName(name)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "DELETE_PRIVATE_SERVER_ERROR",
                            e.localizedMessage ?: "Error deleting private server",
                            e
                        )
                    }
                }
            }

            Methods.UpdatePrivateServerName.method -> {
                scope.launch {
                    result.runCatching {
                        val oldName = call.argument<String>("oldName") ?: error("Missing oldName")
                        val newName = call.argument<String>("newName") ?: error("Missing newName")
                        Mobile.updatePrivateServerName(oldName, newName)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "UPDATE_PRIVATE_SERVER_NAME_ERROR",
                            e.localizedMessage ?: "Error updating private server name",
                            e
                        )
                    }
                }
            }

            Methods.GetSplitTunnelItems.method -> {
                scope.launch {
                    result.runCatching {
                        val filterType =
                            call.argument<String>("filterType") ?: error("Missing filterType")
                        val json = Mobile.getSplitTunnelItems(filterType)
                        withContext(Dispatchers.Main) { success(json) }
                    }.onFailure { e ->
                        result.error(
                            "GET_SPLIT_TUNNEL_ITEMS_ERROR",
                            e.localizedMessage ?: "Failed to get split tunnel items",
                            e
                        )
                    }
                }
            }

            Methods.GetSplitTunnelState.method -> {
                scope.launch {
                    result.runCatching {
                        val json = Mobile.getSplitTunnelStateJSON()
                        withContext(Dispatchers.Main) { success(json) }
                    }.onFailure { e ->
                        result.error(
                            "GET_SPLIT_TUNNEL_STATE_ERROR",
                            e.localizedMessage ?: "Failed to get split tunnel state",
                            e
                        )
                    }
                }
            }

            Methods.FeatureFlag.method -> {
                scope.launch {
                    result.runCatching {
                        val flags = Mobile.availableFeatures()
                        withContext(Dispatchers.Main) {
                            success(if (flags.isEmpty()) "{}" else flags)
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

            Methods.InstallSideloadUpdate.method -> {
                scope.launch {
                    result.runCatching {
                        val update = AndroidSideloadUpdateRequest(
                            url = call.argument<String>("url") ?: error("Missing url"),
                            checksum = call.argument<String>("checksum")
                                ?: error("Missing checksum"),
                            version = call.argument<String>("version")
                                ?: error("Missing version"),
                        )
                        val status =
                            AndroidSideloadInstaller.install(MainActivity.instance, update)
                        withContext(Dispatchers.Main) {
                            result.success(status)
                        }

                    }.onFailure { e ->
                        result.error(
                            "install_sideload_update",
                            e.localizedMessage ?: "Failed to install sideload update",
                            e
                        )
                    }
                }
            }

            //Change Email
            Methods.VerifyPassword.method -> {
                scope.launch {
                    result.runCatching {
                        val map = call.arguments as Map<*, *>
                        val email = map["email"] as String? ?: error("Missing email")
                        val password = map["password"] as String? ?: error("Missing password")
                        Mobile.verifyPassword(email, password)
                        withContext(Dispatchers.Main) {
                            success("ok")
                        }
                    }.onFailure { e ->
                        result.error(
                            "VerifyPassword",
                            e.localizedMessage ?: "Error while verifying password",
                            e
                        )
                    }
                }
            }

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
                            success(if (data.isEmpty()) "[]" else data)
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

            Methods.GetSelectedServerJSON.method -> {
                scope.handleValue(result, "get_selected_server_json") {
                    val data = Mobile.getSelectedServerJSON()
                    if (data.isNullOrEmpty()) "{}" else data
                }
            }

            Methods.UpdateTelemetryEvents.method -> {
                scope.handleResult(result, "UpdateTelemetryEvents") {
                    val consent = call.arguments as Boolean
                    Mobile.updateTelemetryConsent(consent)
                }
            }

            Methods.SetRoutingMode.method -> {
                scope.handleResult(result, "SetRoutingMode") {
                    val enable = call.arguments as Boolean
                    Mobile.setSmartRoutingEnabled(enable)
                }
            }

            Methods.IsSmartRoutingEnabled.method -> {
                scope.handleValue(result, "is_smart_routing_enabled") {
                    Mobile.isSmartRoutingEnabled()
                }
            }

            // Share My Connection (samizdat) + Unbounded (broflake)
            // peer-share. Phones on mobile data won't have UPnP, but
            // home WiFi does — manual port forwarding works there too,
            // so the whole stack is exposed on Android rather than
            // desktop-only.
            Methods.SetPeerProxyEnabled.method -> {
                scope.handleResult(result, "set_peer_proxy_enabled") {
                    val enabled = call.argument<Boolean>("enabled")
                        ?: error("Missing enabled")
                    Mobile.setPeerShareEnabled(enabled)
                }
            }

            Methods.IsPeerProxyEnabled.method -> {
                scope.handleValue(result, "is_peer_proxy_enabled") {
                    Mobile.isPeerShareEnabled()
                }
            }

            Methods.SetPeerManualPort.method -> {
                scope.handleResult(result, "set_peer_manual_port") {
                    // error() surfaces the failure rather than silently
                    // defaulting to 0 — which would clear the user's
                    // manual port override on caller bugs. Matches the
                    // SetPeerProxyEnabled pattern above.
                    val port = call.argument<Int>("port") ?: error("Missing port")
                    Mobile.setPeerManualPort(port.toLong())
                }
            }

            Methods.GetPeerManualPort.method -> {
                scope.handleValue(result, "get_peer_manual_port") {
                    Mobile.getPeerManualPort().toInt()
                }
            }

            // Returns the marshalled radiance peer.Status, or "" when it
            // could not be read. The peer-status event stream carries
            // transitions only, and peer sharing resumes from persisted
            // settings before the UI is listening, so the UI needs to be
            // able to ask outright.
            Methods.GetPeerStatus.method -> {
                scope.handleValue(result, "get_peer_status") {
                    Mobile.getPeerStatus()
                }
            }

            Methods.SetUnboundedEnabled.method -> {
                scope.handleResult(result, "set_unbounded_enabled") {
                    val enabled = call.argument<Boolean>("enabled")
                        ?: error("Missing enabled")
                    Mobile.setUnboundedEnabled(enabled)
                }
            }

            Methods.IsUnboundedEnabled.method -> {
                scope.handleValue(result, "is_unbounded_enabled") {
                    Mobile.isUnboundedEnabled()
                }
            }

            Methods.ProbeUPnP.method -> {
                // UPnP M-SEARCH waits up to ~6s on multicast replies;
                // handleValue is already coroutine-backed (Dispatchers.IO
                // via scope), so the wait runs off the main thread and
                // doesn't block the Flutter UI isolate.
                scope.handleValue(result, "probe_upnp") {
                    Mobile.probeUPnP()
                }
            }

            Methods.IsTelemetryEnabled.method -> {
                scope.handleValue(result, "is_telemetry_enabled") {
                    Mobile.isTelemetryEnabled()
                }
            }

            Methods.IsOAuthLogin.method -> {
                scope.handleValue(result, "is_oauth_login") {
                    Mobile.isOAuthLogin()
                }
            }

            Methods.GetOAuthProvider.method -> {
                scope.handleValue(result, "get_oauth_provider") {
                    Mobile.getOAuthProvider()
                }
            }

            Methods.CheckVpnConflict.method -> {
                scope.launch {
                    runCatching {
                        val hasConflict = isAnotherVpnActive(appContext)
                        withContext(Dispatchers.Main) {
                            result.success(hasConflict)
                        }
                    }.onFailure { e ->
                        withContext(Dispatchers.Main) {
                            result.error("check_vpn_conflict", e.localizedMessage ?: "Error", e)
                        }
                    }
                }
            }

            Methods.PatchSettings.method -> {
                scope.handleResult(result, "patch_settings") {
                    val payload = call.arguments as? String
                        ?: error("Missing settings JSON")
                    Mobile.patchSettings(payload)
                }
            }

            Methods.GetSettings.method -> {
                scope.handleValue(result, "get_settings") {
                    Mobile.getSettings()
                }
            }

            Methods.PatchEnvVars.method -> {
                scope.handleValue(result, "patch_env_vars") {
                    val payload = call.arguments as? String
                        ?: error("Missing env JSON")
                    Mobile.patchEnvVars(payload)
                }
            }

            Methods.GetEnvVars.method -> {
                scope.handleValue(result, "get_env_vars") {
                    Mobile.getEnvVars()
                }
            }

            Methods.RunURLTests.method -> {
                scope.handleResult(result, "run_url_tests") {
                    Mobile.runURLTests()
                }
            }

            Methods.SendConfigRequest.method -> {
                scope.handleResult(result, "send_config_request") {
                    Mobile.sendConfigRequest()
                }
            }

            Methods.ClearTunnelCache.method -> {
                scope.handleResult(result, "clear_tunnel_cache") {
                    Mobile.clearTunnelCache()
                }
            }

            else -> {
                result.notImplemented()
            }
        }

    }

    private fun launchExternalUrl(url: String): Boolean {
        var currentUrl = url.trim()
        if (currentUrl.isEmpty()) return false

        val visitedUrls = mutableSetOf<String>()
        var fallbackDepth = 0

        while (currentUrl.isNotEmpty()) {
            if (!visitedUrls.add(currentUrl)) {
                AppLogger.w(TAG, "Detected cycle in external URL fallback chain")
                return false
            }

            try {
                if (!currentUrl.startsWith("intent:", ignoreCase = true)) {
                    return startExternalIntent(
                        Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse(currentUrl)
                        )
                    )
                }

                val intent = Intent.parseUri(currentUrl, Intent.URI_INTENT_SCHEME)
                if (startExternalIntent(intent)) {
                    return true
                }

                val fallbackUrl = intent.getStringExtra("browser_fallback_url")?.trim()
                if (fallbackUrl.isNullOrEmpty()) {
                    return false
                }

                fallbackDepth += 1
                if (fallbackDepth > MAX_EXTERNAL_URL_FALLBACK_DEPTH) {
                    AppLogger.w(TAG, "External URL fallback chain exceeded max depth")
                    return false
                }

                currentUrl = fallbackUrl
            } catch (e: Exception) {
                AppLogger.e(TAG, "Unable to launch external URL: ${e.message}")
                return false
            }
        }

        return false
    }

    private fun startExternalIntent(intent: Intent): Boolean {
        intent.addCategory(Intent.CATEGORY_BROWSABLE)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        intent.component = null
        intent.selector = null

        return try {
            appContext.startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            AppLogger.d(TAG, "No activity found for external URL")
            false
        } catch (e: SecurityException) {
            AppLogger.e(TAG, "Unable to launch external URL: ${e.message}")
            false
        }
    }

    private fun isAnotherVpnActive(context: Context): Boolean {
        // If Lantern's own VPN is already connected, there is no external conflict.
        // This avoids false positives when this method is called while Lantern is active.
        if (Mobile.isVPNConnected()) return false

        val cm = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        for (network in cm.allNetworks) {
            val capabilities = cm.getNetworkCapabilities(network) ?: continue
            if (capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN)) {
                return true
            }
        }
        return false
    }
}

private suspend fun MethodChannel.Result.mainSuccess(value: Any? = "ok") =
    withContext(Dispatchers.Main.immediate) { success(value) }

private suspend fun MethodChannel.Result.mainError(
    code: String,
    message: String?,
    details: Any? = null
) = withContext(Dispatchers.Main.immediate) { error(code, message, details) }


private inline fun <T> CoroutineScope.handleValue(
    result: MethodChannel.Result,
    errorCode: String,
    crossinline block: suspend () -> T
) = launch {
    runCatching { block() }
        .onSuccess { v -> result.mainSuccess(v) }
        .onFailure { e ->
            result.mainError(
                errorCode,
                e.localizedMessage ?: "Please try again",
                e
            )
        }
}

private inline fun CoroutineScope.handleResult(
    result: MethodChannel.Result,
    errorCode: String,
    crossinline block: suspend () -> Unit
) = launch {
    runCatching { block() }
        .onSuccess { result.mainSuccess() }
        .onFailure { e ->
            result.mainError(
                errorCode,
                e.localizedMessage ?: "Please try again",
                e
            )
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
        val label = try {
            ri.loadLabel(pm).toString()
        } catch (_: Exception) {
            pkg
        }

        // filter ourselves, and system apps except allowlisted ones
        if (AppFilters.shouldSkip(pkg, ownPkg)) {
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

private fun reportIssueAttachmentsJson(raw: Any?): String {
    val attachments = raw as? List<*> ?: emptyList<Any?>()
    val arr = JSONArray()
    attachments.forEach { item ->
        val attachment = item as? Map<*, *> ?: return@forEach
        arr.put(JSONObject().apply {
            put("name", attachment["name"] as? String ?: "")
            put("path", attachment["path"] as? String ?: "")
            put("mimeType", attachment["mimeType"] as? String ?: "")
            put("sizeBytes", (attachment["sizeBytes"] as? Number)?.toLong() ?: 0L)
        })
    }
    return arr.toString()
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
