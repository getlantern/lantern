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
          self.acknowledgeInAppPurchase(token: token, planId: planId, result: result)
        } else {
          result(
            FlutterError(
              code: "INVALID_ARGUMENTS", message: "Missing or invalid purchaseToken or planId",
              details: nil))
        }
      // user management
      case "logout":
        // Handle logout if needed
        self.logout(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startVPN(result: @escaping FlutterResult) {
    Task {
      do {
        appLogger.info("Received start VPN call")
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
  func logout(result: @escaping FlutterResult) {
    /*
    Task {
      do {
        var error: NSError?
        MobileLogout(&error)
        await MainActor.run {
          result("success")
        }
      } catch {
        await MainActor.run {
          result(
            FlutterError(
              code: "LOGOUT_FAILED",
              message: "Unable to logout.",
              details: error.localizedDescription))
        }
      }
    }
       */
  }

}
