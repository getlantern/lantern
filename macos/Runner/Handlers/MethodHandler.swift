//
//  MethodHandler.swift
//  Lantern
//

import FlutterMacOS
import Foundation
import Liblantern
import NetworkExtension
import StoreKit

/// Handles Flutter method channel interactions for VPN operations.
class MethodHandler {

  private var channel: FlutterMethodChannel

  private var vpnManager: VPNManager

  init(channel: FlutterMethodChannel, vpnManager: VPNManager) {
    self.channel = channel
    self.vpnManager = vpnManager
    setupMethodCallHandler()
  }

  /// Sets up the method call handler for the main method channel.
  private func setupMethodCallHandler() {
    appLogger.info("Setting up method call handler")
    channel.setMethodCallHandler { [self] (call, result) -> Void in

      appLogger.info(String(describing: call.method))
      switch call.method {
      case "startVPN":
        self.startVPN(result: result)
      case "stopVPN":
        self.stopVPN(result: result)
      case "isVPNConnected":
        self.isVPNConnected(result: result)
      case "plans":
        self.plans(result: result)
      case "installedApps":
        self.installedApps(result: result)
      case "addSplitTunnelItem":
        withFilterArgs(call: call, result: result) { filterType, value in
          self.addSplitTunnelItem(result: result, filterType: filterType, value: value)
        }
      case "removeSplitTunnelItem":
        withFilterArgs(call: call, result: result) { filterType, value in
          self.removeSplitTunnelItem(result: result, filterType: filterType, value: value)
        }
      case "addAllItems":
        withFilterArgs(call: call, result: result) { filterType, value in
          self.addAllItemsToSplitTunnel(result: result, filterType: filterType, value: value)
        }
      case "removeAllItems":
        withFilterArgs(call: call, result: result) { filterType, value in
          self.removeItemsToSplitTunnel(result: result, filterType: filterType, value: value)
        }
      case "enableSplitTunneling":
        self.enableSplitTunneling(result: result)
      case "disableSplitTunneling":
        self.disableSplitTunneling(result: result)
      case "connectToServer":
        let map = call.arguments as? [String: Any]
        self.connectToServer(result: result, data: map!)
      case "oauthLoginUrl":
        let provider = call.arguments as! String
        self.oauthLoginUrl(result: result, provider: provider)
      case "oauthLoginCallback":
        let token = call.arguments as! String
        self.oauthLoginCallback(result: result, token: token)
      case "getUserData":
        self.getUserData(result: result)
      case "fetchUserData":
        self.fetchUserData(result: result)
        break
      case "acknowledgeInAppPurchase":
        if let map = call.arguments as? [String: Any],
          let token = map["purchaseToken"] as? String,
          let planId = map["planId"] as? String
        {
          self.acknowledgeInAppPurchase(token: token, planId: planId, result: result)
        } else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENTS", message: "Missing or invalid purchaseToken or planId",
              details: nil))
        }
      // user management
      case "startRecoveryByEmail":
        let map = call.arguments as? [String: Any]
        let email = map?["email"] as? String ?? ""
        self.startRecoveryByEmail(result: result, email: email)
        break
      case "validateRecoveryCode":
        let data = call.arguments as? [String: Any]
        self.validateRecoveryCode(result: result, data: data!)
        break
      case "completeRecoveryByEmail":
        let data = call.arguments as? [String: Any]
        self.completeRecoveryByEmail(result: result, data: data!)
        break
      case "login":
        let data = call.arguments as? [String: Any]
        self.login(result: result, data: data!)
        break
      case "signUp":
        let data = call.arguments as? [String: Any]
        self.signUp(result: result, data: data!)
        break
      case "logout":
        let email = call.arguments as! String
        self.logout(result: result, email: email)
        break
      case "deleteAccount":
        let data = call.arguments as? [String: Any]
        self.deleteAccount(result: result, data: data!)
        break
      case "activationCode":
        let data = call.arguments as? [String: Any]
        self.activationCode(result: result, data: data!)
        break
      case "startChangeEmail":
        self.startChangeEmail(result: result, data: call.arguments as? [String: Any] ?? [:])
        break
      case "completeChangeEmail":
        self.completeChangeEmail(result: result, data: call.arguments as? [String: Any] ?? [:])
        break
      case "removeDevice":
        let data = call.arguments as? [String: Any]
        let deviceId = data?["deviceId"] as? String ?? ""
        self.deviceRemove(result: result, deviceId: deviceId)
        break
      case "attachReferralCode":
        let code = call.arguments as? String ?? ""
        self.referralAttach(result: result, code: code)
        break
      // Private server methods
      case "digitalOcean":
        self.digitalOcean(result: result)
        break
      case "googleCloud":
        self.googleCloud(result: result)
        break
      case "selectAccount":
        let account = call.arguments as? String ?? ""
        self.selectAccount(result: result, account: account)
        break
      case "selectProject":
        let project = call.arguments as? String ?? ""
        self.selectProject(result: result, project: project)
        break
      case "startDeployment":
        let data = call.arguments as? [String: Any]
        self.startDeployment(result: result, data: data!)
        break
      case "cancelDeployment":
        self.cancelDeployment(result: result)
        break
      case "selectCertFingerprint":
        let fingerprint = call.arguments as? String ?? ""
        self.selectCertFingerprint(result: result, fingerprint: fingerprint)
      case "addServerManually":
        let data = call.arguments as? [String: Any]
        self.addServerManually(result: result, data: data!)
      case "inviteToServerManagerInstance":
        let data = call.arguments as? [String: Any]
        self.inviteToServerManagerInstance(result: result, data: data!)
        break

      case "revokeServerManagerInstance":
        let data = call.arguments as? [String: Any]
        self.revokeServerManagerInstance(result: result, data: data!)
        break

      case "validateSession":
        self.validateSession(result: result)
        break
      //Utils methods
      case "featureFlag":
        self.featureFlags(result: result)
      case "triggerSystemExtension":
        self.triggerSystemExtensionFlow(result: result)
      case "isSystemExtensionInstalled":
        self.isSystemExtensionInstalled(result: result)
      case "openSystemExtensionSetting":
        self.openSystemExtensionSetting(result: result)
      case "getDataCapInfo":
        self.getDataCapInfo(result: result)
      case "reportIssue":
        let map = call.arguments as? [String: Any]
        self.reportIssue(result: result, data: map!)
        break
      //Server Selection
      case "getLanternAvailableServers":
        self.getLanternAvailableServers(result: result)
        break
      case "getAutoServerLocation":
        self.getAutoServerLocation(result: result)

      // Payment methods
      case "stripeSubscriptionPaymentRedirect":
        let data = call.arguments as? [String: Any]
        self.stripeSubscriptionPaymentRedirect(result: result, data: data!)
        break
      case "paymentRedirect":
        let data = call.arguments as? [String: Any]
        self.paymentRedirect(result: result, data: data!)
        break
      case "stripeBillingPortal":
        self.stripeBillingPortal(result: result)
        break
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task.detached { [weak self] in
      guard let self = self else { return }
      appLogger.info("Received start VPN call")

      do {
        try await self.vpnManager.startTunnel()
        await MainActor.run {
          result("VPN started successfully.")
        }
      } catch {
        appLogger.error("Failed to start VPN: \(error.localizedDescription)")
        await MainActor.run {
          result(
            FlutterError(
              code: "START_FAILED",
              message: "Unable to start VPN tunnel.",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  private func connectToServer(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      do {
        let location = data["location"] as? String ?? ""
        let serverName = data["serverName"] as? String ?? ""
        try await self.vpnManager.connectToServer(location: location, serverName: serverName)
        await MainActor.run {
          result("VPN connected successfully to \(serverName) at \(location).")
        }
      } catch {
        appLogger.error("Failed to connect to VPN server: \(error.localizedDescription)")
        await MainActor.run {
          result(
            FlutterError(
              code: "CONNECT_TO_SERVER_FAILED",
              message: "Unable to connect to VPN server.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func stopVPN(result: @escaping FlutterResult) {
    Task {
      do {
        try await vpnManager.stopTunnel()
        await MainActor.run {
          result("VPN stopped successfully.")
        }
      } catch {
        appLogger.error("Failed to stop VPN: \(error.localizedDescription)")
        await MainActor.run {
          result(
            FlutterError(
              code: "STOP_FAILED",
              message: "Unable to stop VPN tunnel.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func isVPNConnected(result: @escaping FlutterResult) {
    let status = vpnManager.connectionStatus
    let isConnected = status == .connected
    result(isConnected)
  }

  func addSplitTunnelItem(
    result: @escaping FlutterResult,
    filterType: String,
    value: String
  ) {
    Task {
      var error: NSError?
      MobileAddSplitTunnelItem(filterType, value, &error)
      if let err = error {
        await MainActor.run {
          result(
            FlutterError(
              code: "ADD_SPLIT_TUNNEL_ITEM_FAILED",
              message: err.localizedDescription,
              details: err.debugDescription))
        }
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func removeSplitTunnelItem(
    result: @escaping FlutterResult,
    filterType: String,
    value: String
  ) {
    Task {
      var error: NSError?
      MobileRemoveSplitTunnelItem(filterType, value, &error)
      if let err = error {
        await MainActor.run {
          result(
            FlutterError(
              code: "REMOVE_SPLIT_TUNNEL_ITEM_FAILED",
              message: err.localizedDescription,
              details: err.debugDescription))
        }
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func addAllItemsToSplitTunnel(result: @escaping FlutterResult, filterType: String, value: String)
  {
    Task.detached {
      var error: NSError?
      MobileAddSplitTunnelItems(value, &error)
      if let err = error {
        await self.handleFlutterError(
          err, result: result, code: "ADD_ALL_SPLIT_TUNNEL_ITEMS_FAILED")
        return
      }
      await MainActor.run { result("ok") }

    }
  }

  func removeItemsToSplitTunnel(result: @escaping FlutterResult, filterType: String, value: String)
  {
    Task.detached {
      var error: NSError?
      MobileRemoveSplitTunnelItems(value, &error)
      if let err = error {
        await self.handleFlutterError(
          err, result: result, code: "REMOVE_ALL_SPLIT_TUNNEL_ITEMS_FAILED")
        return
      }
      await MainActor.run { result("ok") }
    }
  }

  func disableSplitTunneling(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      MobileSetSplitTunnelingEnabled(false, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "REPORT_ISSUE_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func enableSplitTunneling(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      MobileSetSplitTunnelingEnabled(true, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "REPORT_ISSUE_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  private func plans(result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        let data = MobilePlans("", &error)
        if error != nil {
          result(
            FlutterError(
              code: "PLANS_ERROR",
              message: error?.description,
              details: error?.localizedDescription))
        }
        await MainActor.run {
          result(data)
        }
      }
    }
  }

  private func installedApps(result: @escaping FlutterResult) {
    Task {
      let dataDir = FilePath.dataDirectory

      var error: NSError?
      let json = MobileLoadInstalledApps(dataDir.path, &error)

      if let err = error {
        result(
          FlutterError(
            code: "INSTALLED_APPS_ERROR",
            message: err.localizedDescription,
            details: err.debugDescription))
        return
      }
      result(json)
    }
  }

  private func oauthLoginUrl(result: @escaping FlutterResult, provider: String) {
    Task {
      do {
        var error: NSError?
        let data = MobileOAuthLoginUrl(provider, &error)
        if error != nil {
          result(
            FlutterError(
              code: "OAUTH_LOGIN",
              message: error?.description,
              details: error?.localizedDescription))
        }
        await MainActor.run {
          result(data)
        }
      }
    }
  }

  private func oauthLoginCallback(result: @escaping FlutterResult, token: String) {
    Task {
      do {
        var error: NSError?
        let data = MobileOAuthLoginCallback(token, &error)
        if error != nil {
          result(
            FlutterError(
              code: "OAUTH_LOGIN_CALLBACK",
              message: error?.description,
              details: error?.localizedDescription))
        }
        await MainActor.run {
          result(data)
        }
      }
    }
  }

  private func getUserData(result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        let data = MobileUserData(&error)
        if error != nil {
          result(
            FlutterError(
              code: "USER_DATA_ERROR",
              message: error?.description,
              details: error?.localizedDescription))
        }
        await MainActor.run {
          result(data)
        }
      }
    }
  }

  private func fetchUserData(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let bytes = MobileFetchUserData(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "FETCH_USER_DATA_ERROR")
        return
      }
      await MainActor.run {
        result(bytes)
      }
    }
  }

  func acknowledgeInAppPurchase(token: String, planId: String, result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        MobileAcknowledgeApplePurchase(token, planId, &error)
        await MainActor.run {
          result("success")
        }
      }
    }
  }

  // User management

  func startRecoveryByEmail(result: @escaping FlutterResult, email: String) {
    Task {
      var error: NSError?
      MobileStartRecoveryByEmail(email, &error)
      if error != nil {
        result(
          FlutterError(
            code: "RECOVERY_FAILED",
            message: error!.localizedDescription,
            details: error!.debugDescription))
        return
      }
      await MainActor.run {
        result("Recovery email sent successfully.")
      }
    }
  }

  func validateRecoveryCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      var error: NSError?
      MobileValidateChangeEmailCode(email, code, &error)
      if error != nil {
        result(
          FlutterError(
            code: error!.localizedDescription,
            message: error!.localizedDescription,
            details: error?.localizedDescription))
        return
      }
      await MainActor.run {
        result("Recovery code validated successfully.")
      }
    }
  }

  func startChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["newEmail"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      MobileStartChangeEmail(email, password, &error)
      if error != nil {
        await self.handleFlutterError(
          error,
          result: result,
          code: "START_CHANGE_EMAIL_FAILED"
        )
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func completeChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      let newPassword = data["newPassword"] as? String ?? ""
      var error: NSError?
      MobileCompleteChangeEmail(email, newPassword, code, &error)
      if error != nil {
        result(
          FlutterError(
            code: "COMPLETE_CHANGE_EMAIL_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result("Change email completed successfully.")
      }
    }
  }

  func deviceRemove(result: @escaping FlutterResult, deviceId: String) {
    Task.detached {
      var error: NSError?
      MobileRemoveDevice(deviceId, &error)
      if error != nil {
        appLogger.error("Failed to remove device: \(error!.localizedDescription)")
        await self.handleFlutterError(
          error,
          result: result,
          code: "REMOVE_DEVICE_FAILED")
        return
      }
      await MainActor.run {
        appLogger.info("Device removed successfully.")
        self.replyOK(result)
      }
    }
  }

  func referralAttach(result: @escaping FlutterResult, code: String) {
    Task.detached {
      var error: NSError?
      MobileReferralAttachment(code, &error)
      if error != nil {
        appLogger.error("Failed to attach referral code: \(error!.localizedDescription)")
        await self.handleFlutterError(
          error,
          result: result,
          code: "ATTACH_REFERRAL_CODE_FAILED")
        return
      }
      await MainActor.run {
        appLogger.info("Referral code attached successfully.")
        self.replyOK(result)
      }
    }
  }

  func completeRecoveryByEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      let newPassword = data["newPassword"] as? String ?? ""
      var error: NSError?
      var data = try await MobileCompleteRecoveryByEmail(email, newPassword, code, &error)
      if error != nil {
        result(
          FlutterError(
            code: "COMPLETE_CHANGE_EMAIL_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result("Change email completed successfully.")
      }
    }
  }

  func login(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      let data = MobileLogin(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "LOGIN_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }
  func signUp(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      MobileSignUp(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "SIGNUP_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func logout(result: @escaping FlutterResult, email: String) {
    Task {
      var error: NSError?
      let data = MobileLogout(email, &error)
      if error != nil {
        result(
          FlutterError(
            code: "LOGOUT_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }

  func deleteAccount(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      let data = MobileDeleteAccount(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "DELETE_ACCOUNT_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }

  func activationCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let resellerCode = data["resellerCode"] as? String ?? ""
      var error: NSError?
      MobileActivationCode(email, resellerCode, &error)
      if error != nil {
        result(
          FlutterError(
            code: "ACTIVATION_CODE_FAILED",
            message: error!.localizedDescription,
            details: error!.localizedDescription))
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  /// Private server methods
  /// Starts the Digital Ocean private server flow.
  func digitalOcean(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      MobileDigitalOceanPrivateServer(PrivateServerListener.shared, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "DIGITAL_OCEAN_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }

    }
  }

  func googleCloud(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      MobileGoogleCloudPrivateServer(PrivateServerListener.shared, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "GOOGLE_CLOUD_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }

    }
  }

  func selectAccount(result: @escaping FlutterResult, account: String) {
    Task.detached {
      var error: NSError?
      MobileSelectAccount(account, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "SELECT_ACCOUNT_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }

    }
  }

  func selectProject(result: @escaping FlutterResult, project: String) {
    Task.detached {

      var error: NSError?
      MobileSelectProject(project, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "SELECT_PROJECT_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }

    }
  }

  func startDeployment(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let location = data["location"] as? String ?? ""
      let serverName = data["serverName"] as? String ?? ""

      var error: NSError?
      let success = MobileStartDeployment(location, serverName, &error)

      if let err = error {
        await self.handleFlutterError(err, result: result, code: "START_DEPLOYMENT_ERROR")
        return
      }

      await MainActor.run {
        result(success ? "ok" : "failed")
      }
    }
  }

  func cancelDeployment(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let success = MobileCancelDeployment(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "CANCEL_DEPLOYMENT_ERROR")
        return
      }
      await MainActor.run {
        result(success ? "ok" : "failed")
      }
    }
  }

  func selectCertFingerprint(result: @escaping FlutterResult, fingerprint: String) {
    Task.detached {
      MobileSelectedCertFingerprint(fingerprint)
      await MainActor.run {
        result("ok")
      }
    }
  }

  func addServerManually(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let ip = data["ip"] as? String
      let port = data["port"] as? String
      let accessToken = data["accessToken"] as? String
      let serverName = data["serverName"] as? String
      var error: NSError?
      MobileAddServerManagerInstance(
        ip, port, accessToken, serverName, PrivateServerListener.shared, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "ADD_SERVER_MANUALLY_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func inviteToServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      var error: NSError?
      let successKey = MobileInviteToServerManagerInstance(
        ip, port, accessToken, inviteName, &error)
      if let err = error {
        await self.handleFlutterError(
          err, result: result, code: "INVITE_TO_SERVER_MANAGER_INSTANCE_ERROR")
        return
      }
      await MainActor.run {
        result(successKey)
      }
    }
  }

  func revokeServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      var error: NSError?
      let successKey = MobileRevokeServerManagerInvite(ip, port, accessToken, inviteName, &error)
      if let err = error {
        await self.handleFlutterError(
          err, result: result, code: "REVOKE_SERVER_MANAGER_INSTANCE_ERROR")
        return
      }
      await self.replyOK(result)
    }
  }

  func validateSession(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let isValid = MobileValidateSession(&error)
      if let err = error {
        await self.handleFlutterError(
          err, result: result, code: "VALIDATE_SESSION_ERROR")
        return
      }
      await self.replyOK(result)
    }
  }

  func featureFlags(result: @escaping FlutterResult) {
    Task.detached {
      let flags = MobileAvailableFeatures()
      await MainActor.run {
        result(String(data: flags!, encoding: .utf8))
      }
    }
  }

  func triggerSystemExtensionFlow(result: @escaping FlutterResult) {
    Task.detached {
      SystemExtensionManager.shared.activateExtension()
      await MainActor.run {
        result("ok")
      }
    }
  }

  //Check if system extension is installed or not
  func isSystemExtensionInstalled(result: @escaping FlutterResult) {
    Task.detached {
      SystemExtensionManager.shared.checkInstallationStatus()
      await MainActor.run {
        result("ok")
      }
    }
  }

  func openSystemExtensionSetting(result: @escaping FlutterResult) {
    SystemExtensionManager.shared.openPrivacyAndSecuritySettings()
    result("ok")
  }

  //Utils method for hanlding Flutter errors
  private func getDataCapInfo(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let json = MobileGetDataCapInfo(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "FETCH_DATA_CAP_INFO_ERROR")
        return
      }
      await MainActor.run {
        result(json ?? "{}")
      }
    }
  }

  func getLanternAvailableServers(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let servers = MobileGetAvailableServers(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "GET_LANTERN_SERVERS_ERROR")
        return
      }
      await MainActor.run {
        result(String(data: servers!, encoding: .utf8))
      }
    }
  }

  func getAutoServerLocation(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let location = MobileGetAutoLocation(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "GET_AUTO_LOCATION_ERROR")
        return
      }
      await MainActor.run {
        result(location)
      }
    }
  }

  func stripeSubscriptionPaymentRedirect(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let email = data["email"] as? String ?? ""
      let planId = data["planId"] as? String ?? ""
      let type = data["type"] as? String ?? ""
      var error: NSError?
      let url = MobileStripeSubscriptionPaymentRedirect(type, planId, email, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "STRIPE_PAYMENT_REDIRECT_ERROR")
        return
      }
      await MainActor.run {
        result(url)
      }
    }
  }

  func paymentRedirect(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let provider = data["provider"] as? String ?? ""
      let planId = data["planId"] as? String ?? ""
      let email = data["email"] as? String ?? ""
      var error: NSError?
      let url = MobilePaymentRedirect(provider, planId, email, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "PAYMENT_REDIRECT_ERROR")
        return
      }
      await MainActor.run {
        result(url)
      }
    }
  }

  func stripeBillingPortal(result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      let url = MobileStripeBillingPortalUrl(&error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "STRIPE_BILLING_PORTAL_ERROR")
        return
      }
      await MainActor.run {
        result(url)
      }
    }
  }

  func reportIssue(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let email = data["email"] as? String ?? ""
      let issueType = data["issueType"] as? String ?? ""
      let description = data["description"] as? String ?? ""
      let device = data["device"] as? String ?? ""
      let model = data["model"] as? String ?? ""

      var error: NSError?
      MobileReportIssue(email, issueType, description, device, model, "", &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "REPORT_ISSUE_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  //Utils method for handling Flutter errors
  private func handleFlutterError(
    _ error: Error?,
    result: @escaping FlutterResult,
    code: String = "UNKNOWN_ERROR"
  ) async {
    guard let error = error else { return }

    let nsError = error as NSError
    await MainActor.run {
      result(
        FlutterError(
          code: code,
          message: nsError.localizedDescription,
          details: nsError.debugDescription
        )
      )
    }
  }

  private func withFilterArgs(
    call: FlutterMethodCall,
    result: @escaping FlutterResult,
    perform: (_ filterType: String, _ value: String) -> Void
  ) {
    if let map = call.arguments as? [String: Any],
      let filterType = map["filterType"] as? String,
      let value = map["value"] as? String
    {
      perform(filterType, value)
    } else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing filterType or value",
          details: nil
        )
      )
    }
  }

  @MainActor
  private func replyOK(_ result: FlutterResult) {
    result("ok")
  }

}
