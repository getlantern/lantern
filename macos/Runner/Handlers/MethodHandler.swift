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

  init(channel: FlutterMethodChannel, vpnManager: VPNManager = VPNManager.shared) {
    self.channel = channel
    self.vpnManager = vpnManager
    setupMethodCallHandler()
  }

  /// Sets up the method call handler for the main method channel.
  private func setupMethodCallHandler() {
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {
      case "startVPN":
        self.startVPN(result: result)

      case "connectToServer":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.connectToServer(result: result, data: data)

      case "stopVPN":
        self.stopVPN(result: result)

      case "isVPNConnected":
        self.isVPNConnected(result: result)

      case "plans":
        self.plans(result: result)

      case "oauthLoginUrl":
        guard let provider: String = self.decodeValue(from: call.arguments, result: result) else {
          return
        }
        self.oauthLoginUrl(result: result, provider: provider)

      case "oauthLoginCallback":
        guard let token: String = self.decodeValue(from: call.arguments, result: result) else {
          return
        }
        self.oauthLoginCallback(result: result, token: token)

      case "getUserData":
        self.getUserData(result: result)

      case "fetchUserData":
        self.fetchUserData(result: result)

      case "getDataCapInfo":
        self.getDataCapInfo(result: result)

      case "acknowledgeInAppPurchase":
        guard
          let map = call.arguments as? [String: Any],
          let token = map["purchaseToken"] as? String,
          let planId = map["planId"] as? String
        else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENTS",
              message: "Missing or invalid purchaseToken or planId",
              details: nil
            )
          )
          return
        }
        self.acknowledgeInAppPurchase(token: token, planId: planId, result: result)

      // user management
      case "startRecoveryByEmail":
        let map = (call.arguments as? [String: Any]) ?? [:]
        let email = map["email"] as? String ?? ""
        self.startRecoveryByEmail(result: result, email: email)

      case "validateRecoveryCode":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.validateRecoveryCode(result: result, data: data)

      case "completeRecoveryByEmail":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.completeRecoveryByEmail(result: result, data: data)

      case "login":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.login(result: result, data: data)

      case "signUp":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.signUp(result: result, data: data)

      case "logout":
        guard let email: String = self.decodeValue(from: call.arguments, result: result) else {
          return
        }
        self.logout(result: result, email: email)

      case "deleteAccount":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.deleteAccount(result: result, data: data)

      case "activationCode":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.activationCode(result: result, data: data)

      case "startChangeEmail":
        self.startChangeEmail(
          result: result,
          data: call.arguments as? [String: Any] ?? [:]
        )

      case "completeChangeEmail":
        self.completeChangeEmail(
          result: result,
          data: call.arguments as? [String: Any] ?? [:]
        )

      case "removeDevice":
        let data = call.arguments as? [String: Any]
        let deviceId = data?["deviceId"] as? String ?? ""
        self.deviceRemove(result: result, deviceId: deviceId)

      case "attachReferralCode":
        let code = call.arguments as? String ?? ""
        self.referralAttach(result: result, code: code)

      // Private server methods
      case "digitalOcean":
        self.digitalOcean(result: result)

      case "selectAccount":
        let account = call.arguments as? String ?? ""
        self.selectAccount(result: result, account: account)

      case "selectProject":
        let project = call.arguments as? String ?? ""
        self.selectProject(result: result, project: project)

      case "startDeployment":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.startDeployment(result: result, data: data)

      case "cancelDeployment":
        self.cancelDeployment(result: result)

      case "selectCertFingerprint":
        let fingerprint = call.arguments as? String ?? ""
        self.selectCertFingerprint(result: result, fingerprint: fingerprint)

      case "addServerManually":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.addServerManually(result: result, data: data)

      case "inviteToServerManagerInstance":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.inviteToServerManagerInstance(result: result, data: data)

      case "revokeServerManagerInstance":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.revokeServerManagerInstance(result: result, data: data)

      case "validateSession":
        self.validateSession(result: result)

      // Server Selection
      case "getLanternAvailableServers":
        self.getLanternAvailableServers(result: result)

      case "getAutoServerLocation":
        self.getAutoServerLocation(result: result)

      // Utils
      case "featureFlag":
        self.featureFlags(result: result)

      case "updateLocale":
        let locale = call.arguments as? String ?? ""
        self.updateLocale(result: result, locale: locale)

      case "reportIssue":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.reportIssue(result: result, data: data)

      case "setBlockAdsEnabled":
        let data = call.arguments as? [String: Any]
        let enabled = data?["enabled"] as? Bool ?? false
        self.setBlockAdsEnabled(result: result, enabled: enabled)

      // Macos System extension methods
      case "triggerSystemExtension":
        self.triggerSystemExtensionFlow(result: result)
      case "isSystemExtensionInstalled":
        self.isSystemExtensionInstalled(result: result)
      case "openSystemExtensionSetting":
        self.openSystemExtensionSetting(result: result)

      //Payment methods
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

      //Spilt Tunnling
      case "installedApps":
        self.installedApps(result: result)

      case "isSplitTunnelingEnabled":
        Task.detached {
          let enabled = MobileIsSplitTunnelingEnabled()
          await MainActor.run { result(enabled) }
        }

      case "disableSplitTunneling":
        self.disableSplitTunneling(result: result)

      case "setSplitTunnelingEnabled":
        let enabled: Bool = requireArg(call: call, name: "enabled", result: result)!
        self.setSplitTunnelingEnabled(enabled: enabled, result: result)

      case "addSplitTunnelItem":
        let filterType: String = requireArg(call: call, name: "filterType", result: result)!
        let value: String = requireArg(call: call, name: "value", result: result)!
        self.addSplitTunnelItem(result: result, filterType: filterType, value: value)

      case "removeSplitTunnelItem":
        let filterType: String = requireArg(call: call, name: "filterType", result: result)!
        let value: String = requireArg(call: call, name: "value", result: result)!
        self.removeSplitTunnelItem(result: result, filterType: filterType, value: value)

      case "addAllItems":
        let value: String = requireArg(call: call, name: "value", result: result)!
        self.addAllItemsToSplitTunnel(result: result, value: value)

      case "removeAllItems":
        let value: String = requireArg(call: call, name: "value", result: result)!
        self.removeItemsToSplitTunnel(result: result, value: value)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task {
      do {
        try await vpnManager.startTunnel()
        await MainActor.run {
          result("VPN started successfully.")
        }
      } catch {
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
    Task {
      do {
        let location = data["location"] as? String ?? ""
        let serverName = data["serverName"] as? String ?? ""
        try await self.vpnManager.connectToServer(location: location, serverName: serverName)
        await MainActor.run {
          result("VPN connected successfully to \(serverName) at \(location).")
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "CONNECT_TO_SERVER_FAILED",
              message: "Unable to connect to VPN server.",
              details: error.localizedDescription
            )
          )
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
        await MainActor.run {
          result(
            FlutterError(
              code: "STOP_FAILED",
              message: "Unable to stop VPN tunnel.",
              details: error.localizedDescription
            )
          )
        }
      }
    }
  }

  private func isVPNConnected(result: @escaping FlutterResult) {
    let status = vpnManager.connectionStatus
    let isConnected = status == .connected
    result(isConnected)
  }

  // MARK: - Plans / OAuth / User data

  private func plans(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let data = MobilePlans("non-store", &error)

      if let error {
        await self.handleFlutterError(error, result: result, code: "PLANS_ERROR")
        return
      }

      await MainActor.run {
        result(data)
      }
    }
  }

  private func oauthLoginUrl(result: @escaping FlutterResult, provider: String) {
    Task {
      var error: NSError?
      let data = MobileOAuthLoginUrl(provider, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "OAUTH_LOGIN")
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }

  private func oauthLoginCallback(result: @escaping FlutterResult, token: String) {
    Task {
      var error: NSError?
      let data = MobileOAuthLoginCallback(token, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "OAUTH_LOGIN_CALLBACK")
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }

  private func getUserData(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let data = MobileUserData(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "USER_DATA_ERROR")
        return
      }
      await MainActor.run {
        result(data)
      }
    }
  }

  private func getDataCapInfo(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      if let bytes = MobileGetDataCapInfo(&error) {
        let json = String(data: bytes as Data, encoding: .utf8) ?? "{}"
        await MainActor.run { result(json) }
      } else if let error {
        await self.handleFlutterError(error, result: result, code: "FETCH_DATA_CAP_INFO_FAILED")
      } else {
        await MainActor.run { result("{}") }
      }
    }
  }

  private func fetchUserData(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let bytes = MobileFetchUserData(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "FETCH_USER_DATA_ERROR")
        return
      }
      await MainActor.run {
        result(bytes)
      }
    }
  }

  func acknowledgeInAppPurchase(token: String, planId: String, result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      MobileAcknowledgeApplePurchase(token, planId, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "ACKNOWLEDGE_FAILED")
        return
      }
      await self.replyOK(result)
    }
  }

  // MARK: - User management

  func startRecoveryByEmail(result: @escaping FlutterResult, email: String) {
    Task {
      var error: NSError?
      MobileStartRecoveryByEmail(email, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "RECOVERY_FAILED")
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
      if let error {
        await self.handleFlutterError(error, result: result, code: "VALIDATE_RECOVERY_CODE_FAILED")
        return
      }
      await MainActor.run {
        result("Recovery code validated successfully.")
      }
    }
  }

  func completeRecoveryByEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      let newPassword = data["newPassword"] as? String ?? ""
      var error: NSError?
      MobileCompleteRecoveryByEmail(email, newPassword, code, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "COMPLETE_RECOVERY_FAILED")
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
      let payload = MobileLogin(email, password, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "LOGIN_FAILED")
        return
      }
      await MainActor.run {
        result(payload)
      }
    }
  }

  func signUp(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      MobileSignUp(email, password, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "SIGNUP_FAILED")
        return
      }
      await self.replyOK(result)
    }
  }

  func logout(result: @escaping FlutterResult, email: String) {
    Task {
      var error: NSError?
      let payload = MobileLogout(email, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "LOGOUT_FAILED")
        return
      }
      await MainActor.run {
        result(payload)
      }
    }
  }

  func deleteAccount(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      let payload = MobileDeleteAccount(email, password, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "DELETE_ACCOUNT_FAILED")
        return
      }
      await MainActor.run {
        result(payload)
      }
    }
  }

  func activationCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let resellerCode = data["resellerCode"] as? String ?? ""
      var error: NSError?
      MobileActivationCode(email, resellerCode, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "ACTIVATION_CODE_FAILED")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func startChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["newEmail"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      MobileStartChangeEmail(email, password, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "START_CHANGE_EMAIL_FAILED")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func completeChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let newEmail = data["newEmail"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      let code = data["code"] as? String ?? ""

      var error: NSError?
      MobileCompleteChangeEmail(newEmail, password, code, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "COMPLETE_CHANGE_EMAIL_FAILED")
        return
      }

      await self.replyOK(result)
    }
  }

  func deviceRemove(result: @escaping FlutterResult, deviceId: String) {
    Task {
      var error: NSError?
      MobileRemoveDevice(deviceId, &error)
      if let error {
        appLogger.error("Failed to remove device: \(error.localizedDescription)")
        await self.handleFlutterError(error, result: result, code: "REMOVE_DEVICE_FAILED")
        return
      }
      await MainActor.run {
        appLogger.info("Device removed successfully.")
        result("ok")
      }
    }
  }

  func referralAttach(result: @escaping FlutterResult, code: String) {
    Task {
      var error: NSError?
      MobileReferralAttachment(code, &error)
      if let error {
        appLogger.error("Failed to attach referral code: \(error.localizedDescription)")
        await self.handleFlutterError(error, result: result, code: "ATTACH_REFERRAL_CODE_FAILED")
        return
      }
      await MainActor.run {
        appLogger.info("Referral code attached successfully.")
        result("ok")
      }
    }
  }

  // MARK: - Private server methods

  func digitalOcean(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      MobileDigitalOceanPrivateServer(PrivateServerListener.shared, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "DIGITAL_OCEAN_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func selectAccount(result: @escaping FlutterResult, account: String) {
    Task {
      var error: NSError?
      MobileSelectAccount(account, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "SELECT_ACCOUNT_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func selectProject(result: @escaping FlutterResult, project: String) {
    Task {
      var error: NSError?
      MobileSelectProject(project, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "SELECT_PROJECT_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func startDeployment(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let location = data["location"] as? String ?? ""
      let serverName = data["serverName"] as? String ?? ""

      var error: NSError?
      let success = MobileStartDeployment(location, serverName, &error)

      if let error {
        await self.handleFlutterError(error, result: result, code: "START_DEPLOYMENT_ERROR")
        return
      }

      await MainActor.run {
        result(success ? "ok" : "failed")
      }
    }
  }

  func cancelDeployment(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let success = MobileCancelDeployment(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "CANCEL_DEPLOYMENT_ERROR")
        return
      }
      await MainActor.run {
        result(success ? "ok" : "failed")
      }
    }
  }

  func selectCertFingerprint(result: @escaping FlutterResult, fingerprint: String) {
    Task {
      MobileSelectedCertFingerprint(fingerprint)
      await MainActor.run {
        result("ok")
      }
    }
  }

  func addServerManually(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String
      let port = data["port"] as? String
      let accessToken = data["accessToken"] as? String
      let serverName = data["serverName"] as? String
      var error: NSError?
      MobileAddServerManagerInstance(
        ip, port, accessToken, serverName, PrivateServerListener.shared, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "ADD_SERVER_MANUALLY_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func inviteToServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      var error: NSError?
      let successKey = MobileInviteToServerManagerInstance(
        ip, port, accessToken, inviteName, &error)
      if let error {
        await self.handleFlutterError(
          error, result: result, code: "INVITE_TO_SERVER_MANAGER_INSTANCE_ERROR")
        return
      }
      await MainActor.run {
        result(successKey)
      }
    }
  }

  func revokeServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      var error: NSError?
      _ = MobileRevokeServerManagerInvite(ip, port, accessToken, inviteName, &error)
      if let error {
        await self.handleFlutterError(
          error, result: result, code: "REVOKE_SERVER_MANAGER_INSTANCE_ERROR")
        return
      }
      await self.replyOK(result)
    }
  }

  func validateSession(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      MobileValidateSession(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "VALIDATE_SESSION_ERROR")
        return
      }
      await self.replyOK(result)
    }
  }

  // MARK: - Feature flags / locale / servers / issues

  func featureFlags(result: @escaping FlutterResult) {
    Task {
      let flags = MobileAvailableFeatures()
      guard let flags else {
        await MainActor.run {
          result("{}")
        }
        return
      }
      await MainActor.run {
        result(String(data: flags, encoding: .utf8))
      }
    }
  }

  func updateLocale(result: @escaping FlutterResult, locale: String) {
    Task {
      var error: NSError?
      MobileUpdateLocale(locale, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "UPDATE_LOCALE_ERROR")
        return
      }
      await self.replyOK(result)
    }
  }

  func getLanternAvailableServers(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let servers = MobileGetAvailableServers(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "GET_LANTERN_SERVERS_ERROR")
        return
      }
      guard let servers else {
        await MainActor.run { result("[]") }
        return
      }
      await MainActor.run {
        result(String(data: servers, encoding: .utf8))
      }
    }
  }

  func getAutoServerLocation(result: @escaping FlutterResult) {
    Task {
      var error: NSError?
      let location = MobileGetAutoLocation(&error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "GET_AUTO_LOCATION_ERROR")
        return
      }
      await MainActor.run {
        result(location)
      }
    }
  }

  func reportIssue(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let issueType = data["issueType"] as? String ?? ""
      let description = data["description"] as? String ?? ""
      let device = data["device"] as? String ?? ""
      let model = data["model"] as? String ?? ""
      let logFilePath = data["logFilePath"] as? String ?? ""

      var error: NSError?
      MobileReportIssue(email, issueType, description, device, model, logFilePath, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "REPORT_ISSUE_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func setBlockAdsEnabled(result: @escaping FlutterResult, enabled: Bool) {
    Task {
      var error: NSError?
      MobileSetBlockAdsEnabled(enabled, &error)
      if let error {
        await self.handleFlutterError(error, result: result, code: "SET_BLOCK_ADS_ERROR")
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  // Payment Methods
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

  // Macos System extension methods
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

  // Split Tunneling Methods

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

  func addSplitTunnelItem(
    result: @escaping FlutterResult,
    filterType: String,
    value: String
  ) {
    Task {
      var error: NSError?
      MobileAddSplitTunnelItem(filterType, value, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "ADD_SPLIT_TUNNEL_ITEM_FAILED")
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

  func addAllItemsToSplitTunnel(result: @escaping FlutterResult, value: String) {
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

  func removeItemsToSplitTunnel(result: @escaping FlutterResult, value: String) {
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

  private func setSplitTunnelingEnabled(enabled: Bool, result: @escaping FlutterResult) {
    Task.detached {
      var error: NSError?
      MobileSetSplitTunnelingEnabled(enabled, &error)
      if let err = error {
        await self.handleFlutterError(err, result: result, code: "SET_SPLIT_TUNNELING_FAILED")
        return
      }
      await MainActor.run { result("ok") }
    }
  }

  // MARK: - Utils

  /// Helper for handling Flutter errors
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

  @MainActor
  private func replyOK(_ result: FlutterResult) {
    result("ok")
  }

  // MARK: - Argument helpers

  private func decodeDict(
    from arguments: Any?,
    result: @escaping FlutterResult,
    code: String = "INVALID_ARGUMENTS"
  ) -> [String: Any]? {
    guard let dict = arguments as? [String: Any] else {
      result(
        FlutterError(
          code: code,
          message: "Missing or invalid arguments",
          details: nil
        )
      )
      return nil
    }
    return dict
  }

  private func decodeValue<T>(
    from arguments: Any?,
    result: @escaping FlutterResult,
    code: String = "INVALID_ARGUMENTS"
  ) -> T? {
    guard let value = arguments as? T else {
      result(
        FlutterError(
          code: code,
          message: "Missing or invalid arguments",
          details: nil
        )
      )
      return nil
    }
    return value
  }

  func requireArg<T>(
    call: FlutterMethodCall,
    name: String,
    result: FlutterResult
  ) -> T? {
    guard
      let arguments = call.arguments as? [String: Any],
      let value = arguments[name] as? T
    else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "Missing or invalid argument: \(name)",
          details: nil
        )
      )
      return nil
    }

    return value
  }

}
