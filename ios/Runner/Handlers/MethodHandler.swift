//
//  MethodHandler.swift
//  Lantern
//

import Flutter
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
      case "stopVPN":
        self.stopVPN(result: result)
      case "isVPNConnected":
        self.isVPNConnected(result: result)
      case "plans":
        self.plans(result: result)
      case "oauthLoginUrl":
        var provider = call.arguments as! String
        self.oauthLoginUrl(result: result, provider: provider)
      case "oauthLoginCallback":
        var token = call.arguments as! String
        self.oauthLoginCallback(result: result, token: token)
      case "getUserData":
        self.getUserData(result: result)
      case "showManageSubscriptions":
        self.showManageSubscriptions(result: result)
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
      case "validateRecoveryCode":
        let data = call.arguments as? [String: Any]
        self.validateRecoveryCode(result: result, data: data!)
      case "completeChangeEmail":
        let data = call.arguments as? [String: Any]
        self.completeChangeEmail(result: result, data: data!)
      case "login":
        let data = call.arguments as? [String: Any]
        self.login(result: result, data: data!)
      case "signUp":
        let data = call.arguments as? [String: Any]
        self.signUp(result: result, data: data!)
      case "logout":
        let data = call.arguments as? [String: Any]
        let email = data?["email"] as? String ?? ""
        self.logout(result: result, email: email)
      case "deleteAccount":
        let data = call.arguments as? [String: Any]
        self.deleteAccount(result: result, data: data!)
      case "activationCode":
        let data = call.arguments as? [String: Any]
        self.activationCode(result: result, data: data!)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task {
      do {
        print("Received start VPN call")
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

  private func plans(result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        var data = try await MobilePlans("store", &error)
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
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "PLANS_ERROR",
              message: "Unable to fetch plans.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func oauthLoginUrl(result: @escaping FlutterResult, provider: String) {
    Task {
      do {
        var error: NSError?
        var data = try await MobileOAuthLoginUrl(provider, &error)
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
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "OAUTH_LOGIN",
              message: "Unable to login url.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func oauthLoginCallback(result: @escaping FlutterResult, token: String) {
    Task {
      do {
        var error: NSError?
        var data = try await MobileOAuthLoginCallback(token, &error)
        if error != nil {
          result(
            FlutterError(
              code: "OAUTH_LOGIN_CALLBACK",
              message: error!.description,
              details: error!.localizedDescription))
        }
        await MainActor.run {
          result(data)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "OAUTH_LOGIN_CALLBACK",
              message: "error while login callback.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func getUserData(result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        var data = try await MobileUserData(&error)
        if error != nil {
          result(
            FlutterError(
              code: "USER_DATA_ERROR",
              message: error!.description,
              details: error.debugDescription))
        }
        await MainActor.run {
          result(data)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "USER_DATA_ERROR",
              message: "error while getting user data.",
              details: error.localizedDescription))
        }
      }
    }
  }

  private func showManageSubscriptions(result: @escaping FlutterResult) {
    if #available(iOS 15.0, *) {
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
        result(
          FlutterError(
            code: "NO_WINDOW_SCENE",
            message: "No active window scene found",
            details: nil))
        return
      }

      Task {
        do {
          try await AppStore.showManageSubscriptions(in: windowScene)
          result(nil)
        } catch {
          result(
            FlutterError(
              code: "FAILED_TO_OPEN",
              message: "Failed to show subscriptions: \(error.localizedDescription)",
              details: nil))
        }
      }
    } else {
      result(
        FlutterError(
          code: "UNAVAILABLE",
          message: "iOS 15 or higher is required to manage subscriptions natively",
          details: nil))
    }
  }

  func acknowledgeInAppPurchase(token: String, planId: String, result: @escaping FlutterResult) {
    Task {
      do {
        var error: NSError?
        MobileAcknowledgeApplePurchase(token, planId, &error)
        if error != nil {
          result(
            FlutterError(
              code: "ACKNOWLEDGE_FAILED",
              message: error!.localizedDescription,
              details: error!.debugDescription))
          return
        }
        await MainActor.run {
          result("success")
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "ACKNOWLEDGE_FAILED",
              message: "Unable to acknowledge purchase.",
              details: error.localizedDescription))
        }
      }
    }
  }

  // User management

  func startRecoveryByEmail(result: @escaping FlutterResult, email: String) {
    Task {
      var error: NSError?
      var data = try await MobileStartRecoveryByEmail(email, &error)
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
      var data = try await MobileValidateChangeEmailCode(email, code, &error)
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

  func completeChangeEmail(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let code = data["code"] as? String ?? ""
      let newPassword = data["newPassword"] as? String ?? ""
      var error: NSError?
      var data = try await MobileCompleteChangeEmail(email, newPassword, code, &error)
      if error != nil {
        result(
          FlutterError(
            code: "COMPLETE_CHANGE_EMAIL_FAILED",
            message: error!.localizedDescription,
            details: error!))
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
      var data = try await MobileLogin(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "LOGIN_FAILED",
            message: error!.localizedDescription,
            details: error!))
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
      var data = try await MobileSignUp(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "SIGNUP_FAILED",
            message: error!.localizedDescription,
            details: error!))
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

  func logout(result: @escaping FlutterResult, email: String) {
    Task {
      do {
        var error: NSError?
        var data = try await MobileLogout(email, &error)
        await MainActor.run {
          result(data)
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "LOGOUT_FAILED",
              message: error.localizedDescription,
              details: error))
        }
      }
    }
  }

  func deleteAccount(result: @escaping FlutterResult, data: [String: Any]) {
    Task {
      let email = data["email"] as? String ?? ""
      let password = data["password"] as? String ?? ""
      var error: NSError?
      var data = try await MobileDeleteAccount(email, password, &error)
      if error != nil {
        result(
          FlutterError(
            code: "DELETE_ACCOUNT_FAILED",
            message: error!.localizedDescription,
            details: error!))
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
      var data = try await MobileActivationCode(email, resellerCode, &error)
      if error != nil {
        result(
          FlutterError(
            code: "DELETE_ACCOUNT_FAILED",
            message: error!.localizedDescription,
            details: error!))
        return
      }
      await MainActor.run {
        result("ok")
      }
    }
  }

}
