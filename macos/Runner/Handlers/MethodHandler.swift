//
//  MethodHandler.swift
//  Lantern
//

import Cocoa
import FlutterMacOS
import Foundation
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

      case "appIconBytes":
        let args = (call.arguments as? [String: Any]) ?? [:]
        let iconPath = args["iconPath"] as? String ?? ""
        let appPath = args["appPath"] as? String ?? ""
        let sizePx = args["sizePx"] as? Int ?? 48
        self.appIconBytes(result: result, iconPath: iconPath, appPath: appPath, sizePx: sizePx)

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

      case "addServerBasedOnURLs":
        guard let data = self.decodeDict(from: call.arguments, result: result) else { return }
        self.addServerBasedOnURLs(result: result, data: data)

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

      case "updateTelemetryEvents":
        guard let consent: Bool = self.decodeValue(from: call.arguments, result: result) else {
          return
        }
        self.updateTelemetryEvents(consent: consent, result: result)

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
          let enabled = LanternFFI.shared.isSplitTunnelingEnabled()
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

      // Smart routing
      case "setRoutingMode":
        let enable = self.decodeValue(from: call.arguments, result: result) as Bool?
        self.setRoutingMode(result: result, enable: enable ?? false)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task {
      do {
        try await vpnManager.startTunnel()
        do {
          try LanternFFI.shared.startAutoLocationListener()
        } catch {
          appLogger.error("Error getting auto location: \(error.localizedDescription)")
        }
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
        do {
          try LanternFFI.shared.stopAutoLocationListener()
        } catch {
          appLogger.error("Error stopping auto location listener: \(error.localizedDescription)")
        }
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
        do {
          try LanternFFI.shared.stopAutoLocationListener()
        } catch {
          appLogger.error("Error stopping auto location listener: \(error.localizedDescription)")
        }
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
      do {
        let data = try LanternFFI.shared.plans()
        await MainActor.run {
          result(data)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "PLANS_ERROR")
      }
    }
  }

  private func appIconBytes(
    result: @escaping FlutterResult,
    iconPath: String,
    appPath: String,
    sizePx: Int
  ) {
    Task {
      if appPath.isEmpty {
        result(nil)
        return
      }

      let target = CGSize(width: sizePx, height: sizePx)

      let data: Data? = await MainActor.run {
        // Always prefer the bundle path
        let nsImage = NSWorkspace.shared.icon(forFile: appPath)
        return nsImage.pngData(resizeTo: target)
      }

      if let data, !data.isEmpty {
        result(FlutterStandardTypedData(bytes: data))
      } else {
        result(nil)
      }
    }
  }

  private func oauthLoginUrl(result: @escaping FlutterResult, provider: String) {
    Task {
      do {
        let data = try LanternFFI.shared.oauthLoginUrl(provider: provider)
        await MainActor.run {
          result(data)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "OAUTH_LOGIN")
      }
    }
  }

  private func oauthLoginCallback(result: @escaping FlutterResult, token: String) {
    Task {
      do {
        let data = try LanternFFI.shared.oauthLoginCallback(token: token)
        await MainActor.run {
          result(data)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "OAUTH_LOGIN_CALLBACK")
      }
    }
  }

  private func getUserData(result: @escaping FlutterResult) {
    Task {
      do {
        let data = try LanternFFI.shared.getUserData()
        await MainActor.run {
          result(data)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "USER_DATA_ERROR")
      }
    }
  }

  private func getDataCapInfo(result: @escaping FlutterResult) {
    Task {
      do {
        let data = try LanternFFI.shared.getDataCapInfo()
        await MainActor.run {
          result(data)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "FETCH_DATA_CAP_INFO_FAILED")
      }
    }
  }

  private func fetchUserData(result: @escaping FlutterResult) {
    Task {
      do {
        let bytes = try LanternFFI.shared.fetchUserData()
        await MainActor.run {
          result(bytes)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "FETCH_USER_DATA_ERROR")
      }
    }
  }

  func acknowledgeInAppPurchase(token: String, planId: String, result: @escaping FlutterResult) {
    // TODO: Apple in-app purchase acknowledgment not yet implemented in FFI
    Task {
      await MainActor.run {
        result(
          FlutterError(
            code: "NOT_IMPLEMENTED",
            message: "acknowledgeApplePurchase not yet implemented in FFI",
            details: nil))
      }
    }
  }

  // MARK: - User management

  func startRecoveryByEmail(result: @escaping FlutterResult, email: String) {
    Task {
      do {
        try LanternFFI.shared.startRecoveryByEmail(email: email)
        await MainActor.run {
          result("Recovery email sent successfully.")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "RECOVERY_FAILED")
      }
    }
  }

  func validateRecoveryCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      do {
        try LanternFFI.shared.validateRecoveryCode(email: email, code: code)
        await MainActor.run {
          result("Recovery code validated successfully.")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "VALIDATE_RECOVERY_CODE_FAILED")
      }
    }
  }

  func completeRecoveryByEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      let newPassword = data["newPassword"] as? String ?? ""
      do {
        try LanternFFI.shared.completeRecoveryByEmail(
          email: email, newPassword: newPassword, code: code)
        await MainActor.run {
          result("Change email completed successfully.")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "COMPLETE_RECOVERY_FAILED")
      }
    }
  }

  func login(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      do {
        let payload = try LanternFFI.shared.login(email: email, password: password)
        await MainActor.run {
          result(payload)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "LOGIN_FAILED")
      }
    }
  }

  func signUp(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      do {
        try LanternFFI.shared.signup(email: email, password: password)
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(error, result: result, code: "SIGNUP_FAILED")
      }
    }
  }

  func logout(result: @escaping FlutterResult, email: String) {
    Task {
      do {
        let payload = try LanternFFI.shared.logout(email: email)
        await MainActor.run {
          result(payload)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "LOGOUT_FAILED")
      }
    }
  }

  func deleteAccount(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      do {
        let payload = try LanternFFI.shared.deleteAccount(email: email, password: password)
        await MainActor.run {
          result(payload)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "DELETE_ACCOUNT_FAILED")
      }
    }
  }

  func activationCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let resellerCode = data["resellerCode"] as? String ?? ""
      do {
        try LanternFFI.shared.activationCode(email: email, resellerCode: resellerCode)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "ACTIVATION_CODE_FAILED")
      }
    }
  }

  func startChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["newEmail"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      do {
        try LanternFFI.shared.startChangeEmail(newEmail: email, password: password)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "START_CHANGE_EMAIL_FAILED")
      }
    }
  }

  func completeChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let newEmail = data["newEmail"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      let code = data["code"] as? String ?? ""

      do {
        try LanternFFI.shared.completeChangeEmail(newEmail: newEmail, password: password, code: code)
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(error, result: result, code: "COMPLETE_CHANGE_EMAIL_FAILED")
      }
    }
  }

  func deviceRemove(result: @escaping FlutterResult, deviceId: String) {
    Task {
      do {
        try LanternFFI.shared.removeDevice(deviceId: deviceId)
        await MainActor.run {
          appLogger.info("Device removed successfully.")
          result("ok")
        }
      } catch {
        appLogger.error("Failed to remove device: \(error.localizedDescription)")
        await self.handleFFIError(error, result: result, code: "REMOVE_DEVICE_FAILED")
      }
    }
  }

  func referralAttach(result: @escaping FlutterResult, code: String) {
    Task {
      do {
        try LanternFFI.shared.referralAttachment(code: code)
        await MainActor.run {
          appLogger.info("Referral code attached successfully.")
          result("ok")
        }
      } catch {
        appLogger.error("Failed to attach referral code: \(error.localizedDescription)")
        await self.handleFFIError(error, result: result, code: "ATTACH_REFERRAL_CODE_FAILED")
      }
    }
  }

  // MARK: - Private server methods

  func digitalOcean(result: @escaping FlutterResult) {
    Task {
      do {
        try LanternFFI.shared.digitalOceanPrivateServer()
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "DIGITAL_OCEAN_ERROR")
      }
    }
  }

  func selectAccount(result: @escaping FlutterResult, account: String) {
    Task {
      do {
        try LanternFFI.shared.selectAccount(account: account)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "SELECT_ACCOUNT_ERROR")
      }
    }
  }

  func selectProject(result: @escaping FlutterResult, project: String) {
    Task {
      do {
        try LanternFFI.shared.selectProject(project: project)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "SELECT_PROJECT_ERROR")
      }
    }
  }

  func startDeployment(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let location = data["location"] as? String ?? ""
      let serverName = data["serverName"] as? String ?? ""

      do {
        try LanternFFI.shared.startDeployment(location: location, serverName: serverName)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "START_DEPLOYMENT_ERROR")
      }
    }
  }

  func cancelDeployment(result: @escaping FlutterResult) {
    Task {
      do {
        try LanternFFI.shared.cancelDeployment()
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "CANCEL_DEPLOYMENT_ERROR")
      }
    }
  }

  func addServerManually(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let serverName = data["serverName"] as? String ?? ""
      do {
        try LanternFFI.shared.addServerManually(
          ip: ip, port: port, accessToken: accessToken, serverName: serverName)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "ADD_SERVER_MANUALLY_ERROR")
      }
    }
  }

  func inviteToServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      do {
        let successKey = try LanternFFI.shared.inviteToServerManagerInstance(
          ip: ip, port: port, accessToken: accessToken, inviteName: inviteName)
        await MainActor.run {
          result(successKey)
        }
      } catch {
        await self.handleFFIError(
          error, result: result, code: "INVITE_TO_SERVER_MANAGER_INSTANCE_ERROR")
      }
    }
  }

  func revokeServerManagerInstance(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let ip = data["ip"] as? String ?? ""
      let port = data["port"] as? String ?? ""
      let accessToken = data["accessToken"] as? String ?? ""
      let inviteName = data["inviteName"] as? String ?? ""
      do {
        try LanternFFI.shared.revokeServerManagerInvite(
          ip: ip, port: port, accessToken: accessToken, inviteName: inviteName)
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(
          error, result: result, code: "REVOKE_SERVER_MANAGER_INSTANCE_ERROR")
      }
    }
  }

  func validateSession(result: @escaping FlutterResult) {
    Task {
      do {
        try LanternFFI.shared.validateSession()
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(error, result: result, code: "VALIDATE_SESSION_ERROR")
      }
    }
  }

  func addServerBasedOnURLs(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let urls = data["urls"] as? String ?? ""
      let skipVerification = data["skipVerification"] as? Bool ?? false
      let serverName = data["serverName"] as? String ?? ""

      do {
        try LanternFFI.shared.addServerBasedOnURLs(
          urls: urls, skipCertVerification: skipVerification, serverName: serverName)
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(error, result: result, code: "ADD_SERVER_BASED_ON_URLS_ERROR")
      }
    }
  }

  // MARK: - Feature flags / locale / servers / issues

  func featureFlags(result: @escaping FlutterResult) {
    Task {
      let flags = LanternFFI.shared.availableFeatures()
      await MainActor.run {
        if flags.isEmpty {
          result("{}")
        } else {
          result(flags)
        }
      }
    }
  }

  func updateLocale(result: @escaping FlutterResult, locale: String) {
    Task {
      do {
        try LanternFFI.shared.updateLocale(locale: locale)
        await self.replyOK(result)
      } catch {
        await self.handleFFIError(error, result: result, code: "UPDATE_LOCALE_ERROR")
      }
    }
  }

  func getLanternAvailableServers(result: @escaping FlutterResult) {
    Task {
      do {
        let servers = try LanternFFI.shared.getAvailableServers()
        await MainActor.run {
          result(String(data: servers, encoding: .utf8) ?? "[]")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "GET_LANTERN_SERVERS_ERROR")
      }
    }
  }

  func getAutoServerLocation(result: @escaping FlutterResult) {
    Task {
      do {
        let location = try LanternFFI.shared.getAutoLocation()
        await MainActor.run {
          result(location)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "GET_AUTO_LOCATION_ERROR")
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

      do {
        try LanternFFI.shared.reportIssue(
          email: email, issueType: issueType, description: description,
          device: device, model: model, logPath: logFilePath)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "REPORT_ISSUE_ERROR")
      }
    }
  }

  func setBlockAdsEnabled(result: @escaping FlutterResult, enabled: Bool) {
    Task {
      do {
        try LanternFFI.shared.setBlockAdsEnabled(enabled: enabled)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "SET_BLOCK_ADS_ERROR")
      }
    }
  }

  func updateTelemetryEvents(consent: Bool, result: @escaping FlutterResult) {
    Task {
      do {
        try LanternFFI.shared.updateTelemetryConsent(consent: consent)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "UPDATE_TELEMETRY_EVENTS_ERROR")
      }
    }
  }

  // Payment Methods
  func stripeSubscriptionPaymentRedirect(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let email = data["email"] as? String ?? ""
      let planId = data["planId"] as? String ?? ""
      let type = data["type"] as? String ?? ""
      do {
        let url = try LanternFFI.shared.stripeSubscriptionPaymentRedirect(
          type: type, planId: planId, email: email)
        await MainActor.run {
          result(url)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "STRIPE_PAYMENT_REDIRECT_ERROR")
      }
    }
  }

  func paymentRedirect(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      let provider = data["provider"] as? String ?? ""
      let planId = data["planId"] as? String ?? ""
      let email = data["email"] as? String ?? ""
      do {
        let url = try LanternFFI.shared.paymentRedirect(
          provider: provider, planId: planId, email: email)
        await MainActor.run {
          result(url)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "PAYMENT_REDIRECT_ERROR")
      }
    }
  }

  func stripeBillingPortal(result: @escaping FlutterResult) {
    Task.detached {
      do {
        let url = try LanternFFI.shared.stripeBillingPortalUrl()
        await MainActor.run {
          result(url)
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "STRIPE_BILLING_PORTAL_ERROR")
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
      do {
        let json = try LanternFFI.shared.loadInstalledApps()
        result(json)
      } catch {
        result(
          FlutterError(
            code: "INSTALLED_APPS_ERROR",
            message: error.localizedDescription,
            details: nil))
      }
    }
  }

  func addSplitTunnelItem(
    result: @escaping FlutterResult,
    filterType: String,
    value: String
  ) {
    Task {
      do {
        try LanternFFI.shared.addSplitTunnelItem(filterType: filterType, item: value)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "ADD_SPLIT_TUNNEL_ITEM_FAILED")
      }
    }
  }

  func removeSplitTunnelItem(
    result: @escaping FlutterResult,
    filterType: String,
    value: String
  ) {
    Task {
      do {
        try LanternFFI.shared.removeSplitTunnelItem(filterType: filterType, item: value)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "REMOVE_SPLIT_TUNNEL_ITEM_FAILED",
              message: error.localizedDescription,
              details: nil))
        }
      }
    }
  }

  func addAllItemsToSplitTunnel(result: @escaping FlutterResult, value: String) {
    // TODO: Batch split tunnel operations not yet implemented in FFI
    // Fall back to adding items one by one
    Task.detached {
      do {
        if let data = value.data(using: .utf8),
          let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        {
          for item in items {
            if let filterType = item["filterType"], let itemValue = item["item"] {
              try LanternFFI.shared.addSplitTunnelItem(filterType: filterType, item: itemValue)
            }
          }
          await MainActor.run { result("ok") }
        } else {
          await MainActor.run {
            result(
              FlutterError(
                code: "INVALID_FORMAT", message: "Invalid JSON format for split tunnel items",
                details: nil))
          }
        }
      } catch {
        await self.handleFFIError(
          error, result: result, code: "ADD_ALL_SPLIT_TUNNEL_ITEMS_FAILED")
      }
    }
  }

  func removeItemsToSplitTunnel(result: @escaping FlutterResult, value: String) {
    // TODO: Batch split tunnel operations not yet implemented in FFI
    // Fall back to removing items one by one
    Task.detached {
      do {
        if let data = value.data(using: .utf8),
          let items = try? JSONSerialization.jsonObject(with: data) as? [[String: String]]
        {
          for item in items {
            if let filterType = item["filterType"], let itemValue = item["item"] {
              try LanternFFI.shared.removeSplitTunnelItem(filterType: filterType, item: itemValue)
            }
          }
          await MainActor.run { result("ok") }
        } else {
          await MainActor.run {
            result(
              FlutterError(
                code: "INVALID_FORMAT", message: "Invalid JSON format for split tunnel items",
                details: nil))
          }
        }
      } catch {
        await self.handleFFIError(
          error, result: result, code: "REMOVE_ALL_SPLIT_TUNNEL_ITEMS_FAILED")
      }
    }
  }

  func disableSplitTunneling(result: @escaping FlutterResult) {
    Task.detached {
      do {
        try LanternFFI.shared.setSplitTunnelingEnabled(enabled: false)
        await MainActor.run {
          result("ok")
        }
      } catch {
        await self.handleFFIError(error, result: result, code: "REPORT_ISSUE_ERROR")
      }
    }
  }

  private func setSplitTunnelingEnabled(enabled: Bool, result: @escaping FlutterResult) {
    Task.detached {
      do {
        try LanternFFI.shared.setSplitTunnelingEnabled(enabled: enabled)
        await MainActor.run { result("ok") }
      } catch {
        await self.handleFFIError(error, result: result, code: "SET_SPLIT_TUNNELING_FAILED")
      }
    }
  }

  //Smart routing

  private func setRoutingMode(result: @escaping FlutterResult, enable: Bool) {
    Task.detached {
      do {
        try LanternFFI.shared.setSmartRoutingEnabled(enabled: enable)
        await MainActor.run { result("ok") }
      } catch {
        await self.handleFFIError(error, result: result, code: "SET_SMART_ROUTING_MODE_FAILED")
      }
    }
  }

  // MARK: - Utils

  /// Helper for handling FFI errors
  private func handleFFIError(
    _ error: Error,
    result: @escaping FlutterResult,
    code: String = "UNKNOWN_ERROR"
  ) async {
    await MainActor.run {
      result(
        FlutterError(
          code: code,
          message: error.localizedDescription,
          details: nil
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

extension NSImage {
  @MainActor
  fileprivate func pngData(resizeTo targetSize: CGSize) -> Data? {
    // Fast path: try CGImage-backed conversion
    var rect = NSRect(origin: .zero, size: targetSize)
    if let cg = self.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
      let rep = NSBitmapImageRep(cgImage: cg)
      rep.size = targetSize
      return rep.representation(using: .png, properties: [:])
    }

    // Fallback: draw into a bitmap (more reliable for some NSImage types)
    let rep = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: Int(targetSize.width),
      pixelsHigh: Int(targetSize.height),
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    )
    guard let rep else { return nil }

    rep.size = targetSize
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }

    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    self.draw(
      in: NSRect(origin: .zero, size: targetSize),
      from: .zero,
      operation: .sourceOver,
      fraction: 1.0
    )

    return rep.representation(using: .png, properties: [:])
  }
}
