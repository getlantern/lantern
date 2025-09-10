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

  private var core: LanterncoreCore

  init(channel: FlutterMethodChannel, vpnManager: VPNManager, core: LanterncoreCore) {
    self.channel = channel
    self.vpnManager = vpnManager
    self.core = core
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
      case "acknowledgeInAppPurchase":
        if let map = call.arguments as? [String: Any],
          let token = map["purchaseToken"] as? String,
          let planId = map["planId"] as? String
        {
          self.acknowledgeInAppPurchase(token: token, planID: planId, result: result)
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
      case "completeChangeEmail":
        let data = call.arguments as? [String: Any]
        self.completeChangeEmail(result: result, data: data!)
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
        let data = call.arguments as? [String: Any]
        let email = data?["email"] as? String ?? ""
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
      //Utils methods
      case "featureFlag":
        self.featureFlags(result: result)
      default:
        appLogger.error("Unsupported method: \(call.method)")
        result(FlutterMethodNotImplemented)
      }
    }
    channel.invokeMethod("channelReady", arguments: nil)
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task.detached { [weak self] in
      guard let self = self else { return }
      appLogger.info("Received start VPN call")

      // Avoid duplicate starts based on current status
      switch self.vpnManager.connectionStatus {
      case .connected:
        await MainActor.run { result("VPN already connected.") }
        return
      case .connecting, .reasserting:
        await MainActor.run { result("VPN is already starting.") }
        return
      case .disconnecting:
        await MainActor.run {
          result(
            FlutterError(
              code: "START_IN_PROGRESS",
              message: "VPN is currently disconnecting. Try again shortly.",
              details: nil
            )
          )
        }
        return
      default:
        break
      }

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
      do {
        try self.core.addSplitTunnelItem(filterType, item: value)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(
          error, result: result, code: "ADD_SPLIT_TUNNEL_ITEM_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
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
        try self.core.removeSplitTunnelItem(filterType, item: value)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(
          error, result: result, code: "REMOVE_SPLIT_TUNNEL_ITEM_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  private func plans(result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        let data = self.core.plans("", error: &error)
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
      let json = self.core.loadInstalledApps(dataDir.path, error: &error)

      if let err = error {
        result(
          FlutterError(
            code: "INSTALLED_APPS_ERROR",
            message: err.localizedDescription,
            details: err.debugDescription))
        return
      }
      // If json is an empty string, return "[]", otherwise return
      // json
      if json == "" {
        result("[]")
      } else {
        result(json)
      }
    }
  }

  private func oauthLoginUrl(result: @escaping FlutterResult, provider: String) {
    Task {
      do {
        var error: NSError?
        let data = self.core.oAuthLoginUrl(provider, error: &error)
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
        let data = try self.core.oAuthLoginCallback(token)
        await MainActor.run {
          result(data)
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "OAUTH_LOGIN_CALLBACK")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  private func getUserData(result: @escaping FlutterResult) {
    Task {
      do {
        let data = try self.core.userData()
        await MainActor.run {
          result(data)
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "USER_DATA_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func acknowledgeInAppPurchase(token: String, planID: String, result: @escaping FlutterResult) {
    Task {
      do {
        try self.core.acknowledgeApplePurchase(token, planID: planID)
        await MainActor.run {
          result("success")
        }
      } catch let error as NSError {
        await self.handleFlutterError(
          error, result: result, code: "ACKNOWLEDGE_IN_APP_PURCHASE_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  // User management

  func startRecoveryByEmail(result: @escaping FlutterResult, email: String) {
    Task {
      do {
        try self.core.startRecovery(byEmail: email)
        await MainActor.run {
          result("Recovery email sent successfully.")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "RECOVERY_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func validateRecoveryCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let code = data["code"] as? String ?? ""
        try self.core.validateChangeEmailCode(email, code: code)
        await MainActor.run {
          result("Recovery code validated successfully.")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "VALIDATE_RECOVERY_CODE_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func completeChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let code = data["code"] as? String ?? ""
        let newPassword = data["newPassword"] as? String ?? ""
        try self.core.completeChangeEmail(email, password: newPassword, code: code)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "COMPLETE_CHANGE_EMAIL_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func login(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let password = data["password"] as? String ?? ""
        let data = try self.core.login(email, password: password)
        await MainActor.run {
          result(data)
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "LOGIN_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }
  func signUp(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let password = data["password"] as? String ?? ""
        try self.core.signUp(email, password: password)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "SIGNUP_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func logout(result: @escaping FlutterResult, email: String) {
    Task {
      do {
        let data = try self.core.logout(email)
        await MainActor.run {
          result(data)
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "LOGOUT_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }

  }

  func deleteAccount(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let password = data["password"] as? String ?? ""
        let data = try self.core.deleteAccount(email, password: password)
        await MainActor.run {
          result(data)
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "DELETE_ACCOUNT_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func activationCode(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      do {
        let email = data["email"] as? String ?? ""
        let resellerCode = data["resellerCode"] as? String ?? ""
        try self.core.activationCode(email, resellerCode: resellerCode)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "ACTIVATION_CODE_FAILED")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  /// Private server methods
  /// Starts the Digital Ocean private server flow.
  func digitalOcean(result: @escaping FlutterResult) {
    Task.detached {
      do {
        try self.core.digitalOceanPrivateServer(PrivateServerListener.shared)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "DIGITAL_OCEAN_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func googleCloud(result: @escaping FlutterResult) {
    Task.detached {
      do {
        try self.core.googleCloudPrivateServer(PrivateServerListener.shared)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "GOOGLE_CLOUD_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func selectAccount(result: @escaping FlutterResult, account: String) {
    Task.detached {
      do {
        try self.core.selectAccount(account)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "SELECT_ACCOUNT_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func selectProject(result: @escaping FlutterResult, project: String) {
    Task.detached {
      do {
        try self.core.selectProject(project)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "SELECT_PROJECT_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func startDeployment(result: @escaping FlutterResult, data: [String: Any]) {
    Task.detached {
      do {
        let location = data["location"] as? String ?? ""
        let serverName = data["serverName"] as? String ?? ""
        try self.core.startDeployment(location, serverName: serverName)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "START_DEPLOYMENT_ERROR")
        return
      } catch {  // Catch any other error
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func cancelDeployment(result: @escaping FlutterResult) {
    Task.detached {
      do {
        try self.core.cancelDeployment()
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "CANCEL_DEPLOYMENT_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func selectCertFingerprint(result: @escaping FlutterResult, fingerprint: String) {
    Task.detached {
      self.core.selectedCertFingerprint(fingerprint)
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
      do {
        try self.core.addServerManagerInstance(
          ip, port: port, accessToken: accessToken, tag: serverName,
          events: PrivateServerListener.shared)
        await MainActor.run {
          result("ok")
        }
      } catch let error as NSError {
        await self.handleFlutterError(error, result: result, code: "ADD_SERVER_MANUALLY_ERROR")
        return
      } catch {
        appLogger.error("An unexpected error occurred: \(error)")
        result(
          FlutterError(
            code: "UNEXPECTED_ERROR", message: "An unexpected error occurred.", details: "\(error)")
        )
      }
    }
  }

  func featureFlags(result: @escaping FlutterResult) {
    Task.detached {
      let flags = self.core.availableFeatures()
      await MainActor.run {
        result(String(data: flags!, encoding: .utf8))
      }
    }
  }

  // Utils method for handling Flutter errors
  func handleFlutterError(
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

  func withFilterArgs(
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

}
