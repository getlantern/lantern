//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
  //  private var manager: NEVPNManager = NEVPNManager.shared()
  static let shared: VPNManager = VPNManager()

  @Published private(set) var connectionStatus: NEVPNStatus = .disconnected {
    didSet {
      guard oldValue != connectionStatus else { return }
      didUpdateConnectionStatusCallback?(connectionStatus)
    }
  }

  /// Callback closure to notify about connection status updates.
  var didUpdateConnectionStatusCallback: ((NEVPNStatus) -> Void)?

  init() {
    observer = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange, object: nil, queue: nil
    ) { [weak self] notification in
      guard let connection = notification.object as? NEVPNConnection else { return }
      self?.connectionStatus = connection.status
      switch connection.status {
      case .disconnected:
        appLogger.info("VPN disconnected")
      case .invalid:
        appLogger.info("VPN invalid")
      case .connected:
        appLogger.info("VPN connected")
      case .connecting:
        appLogger.info("VPN connecting")
      case .disconnecting:
        appLogger.info("VPN disconnecting")
      case .reasserting:
        appLogger.info("VPN reasserting")
      default:
        appLogger.info("Unknown VPN status: \(connection.status)")
      }
    }

    appLogger.log("VPNManager initialized")
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  // MARK: - VPN Control Methods

  /// Starts the VPN tunnel.
  /// Loads VPN preferences and initiates the VPN connection.

  func startTunnel() async throws {
    guard connectionStatus == .disconnected else {
      appLogger.log("Tunnel already running.")
      return
    }

    //    // ❗️ Now we use `try await` so setupSystemExtension can stop us if we’re not ready
    //    do {
    //      try await setupSystemExtension()
    //    } catch SystemExtensionError.requiresReboot {
    //      // surface a user-friendly message
    //      let msg = "The app needs a reboot to finish installing its network extension."
    //      throw NSError(
    //        domain: "SetupSystemExtensionError",
    //        code: 1001,
    //        userInfo: [NSLocalizedDescriptionKey: msg]
    //      )
    //    } catch {
    //      throw error
    //    }
    // if we get here, the extension is fully installed and ready
    appLogger.log("System extension ready — starting tunnel…")

    guard let manager = await ExtensionProfile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }

    let options: [String: NSObject] = [
      "netEx.Type": "User" as NSString,
      "netEx.StartReason": "User Initiated" as NSString,
    ]

    do {
      try manager.connection.startVPNTunnel(options: options)
      appLogger.log("Tunnel started successfully.")
      /// Enable on-demand to allow automatic reconnections
      /// if error it will stuck in infinite loop
      //self.manager.isOnDemandEnabled = true
      // try await self.saveThenLoadProvider()

    } catch {
      appLogger.error("Failed to start tunnel: \(error.localizedDescription)")
      throw error
    }
  }

  func connectToServer(
    location: String,
    serverName: String,
  ) async throws {
    guard connectionStatus == .disconnected else {
      appLogger.log("Tunnel already running.")
      return
    }

    //    // ❗️ Now we use `try await` so setupSystemExtension can stop us if we’re not ready
    //    do {
    //      try await setupSystemExtension()
    //    } catch SystemExtensionError.requiresReboot {
    //      // surface a user-friendly message
    //      let msg = "The app needs a reboot to finish installing its network extension."
    //      throw NSError(
    //        domain: "SetupSystemExtensionError",
    //        code: 1001,
    //        userInfo: [NSLocalizedDescriptionKey: msg]
    //      )
    //    } catch {
    //      throw error
    //    }
    //    // if we get here, the extension is fully installed and ready
    //    appLogger.log("System extension ready — starting tunnel…")

    guard let manager = await ExtensionProfile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }
    let options: [String: NSObject] = [
      "netEx.Type": "PrivateServer" as NSString,
      "netEx.StartReason": "Private server Initiated" as NSString,
      "netEx.ServerName": serverName as NSString,
      "netEx.Location": location as NSString,
    ]

    try manager.connection.startVPNTunnel(options: options)
    /// Enable on-demand to allow automatic reconnections
    /// if error it will stuck in infinite loop
    //    self.manager.isOnDemandEnabled = true
    //    try await self.saveThenLoadProvider()

  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    appLogger.log("Stopping tunnel..")
    guard connectionStatus == .connected else {
      appLogger.log("In unexpected state: \(connectionStatus)")
      return
    }
    guard let manager = await ExtensionProfile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }

    if manager.isOnDemandEnabled {
      appLogger.info("Turning off on demand..")
      manager.isOnDemandEnabled = false
      try await manager.saveToPreferences()
    }
    manager.connection.stopVPNTunnel()
    appLogger.log("Tunnel stopped.")
  }

  /// MARK: - Extension Communication
  /// Triggers a method in the VPN extension and handles the response.
  //  func triggerExtensionMethod(
  //    methodName: String,
  //    onSuccess: ((String) -> Void)? = nil,
  //    onError: ((Error) -> Void)? = nil
  //  ) {
  //    guard let session = self.manager.connection as? NETunnelProviderSession else {
  //      let error = NSError(
  //        domain: "VPNManager", code: -1,
  //        userInfo: [NSLocalizedDescriptionKey: "Could not get tunnel session"])
  //      appLogger.error("triggerExtensionMethod failed: \(error.localizedDescription)")
  //      onError?(error)
  //      return
  //    }
  //
  //    guard let messageData = methodName.data(using: .utf8) else {
  //      let error = NSError(
  //        domain: "VPNManager", code: 1,
  //        userInfo: [NSLocalizedDescriptionKey: "Invalid method name encoding"])
  //      appLogger.error("Invalid method name encoding")
  //      onError?(error)
  //      return
  //    }
  //
  //    do {
  //      try session.sendProviderMessage(messageData) { responseData in
  //        guard let data = responseData else {
  //          let error = NSError(
  //            domain: "VPNManager", code: -2,
  //            userInfo: [NSLocalizedDescriptionKey: "No response from provider"])
  //          appLogger.error("triggerExtensionMethod failed: \(error.localizedDescription)")
  //          onError?(error)
  //          return
  //        }
  //
  //        // Try to parse the response as JSON
  //        do {
  //          if let responseDict = try JSONSerialization.jsonObject(with: data, options: [])
  //            as? [String: Any],
  //            let errorMessage = responseDict["error"] as? String
  //          {
  //            // If there's an "error" key, trigger the error callback
  //            let error = NSError(
  //              domain: "VPNManager", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
  //            appLogger.error("Error from provider: \(errorMessage)")
  //            onError?(error)
  //          } else {
  //            // If no "error" key, it's a success
  //            if let result = String(data: data, encoding: .utf8) {
  //              appLogger.log("Extension replied: \(result)")
  //              onSuccess?(result)
  //            } else {
  //              let error = NSError(
  //                domain: "VPNManager", code: -4,
  //                userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
  //              appLogger.error("Invalid response format")
  //              onError?(error)
  //            }
  //          }
  //        } catch {
  //          // If the response isn't a valid JSON, it's an error
  //          let parseError = NSError(
  //            domain: "VPNManager", code: -5,
  //            userInfo: [NSLocalizedDescriptionKey: "Failed to parse response as JSON"])
  //          appLogger.error("Failed to parse response: \(error.localizedDescription)")
  //          onError?(parseError)
  //        }
  //      }
  //    } catch {
  //      appLogger.error("triggerExtensionMethod exception: \(error.localizedDescription)")
  //      onError?(error)
  //    }
  //  }

  enum SystemExtensionError: Error {
    case installReturnedNil
    case requiresReboot
    case underlying(Error)
  }
  //
  //  private nonisolated func setupSystemExtension() async throws {
  //    // 1️⃣ Already installed?  Done.
  //    if await SystemExtensionManager.isInstalled() {
  //      appLogger.info("System extension already installed.")
  //      return
  //    }
  //
  //    // 2️⃣ Try to install
  //    do {
  //      guard let result = try await SystemExtensionManager.ac() else {
  //        appLogger.error("SystemExtension.install returned nil.")
  //        throw SystemExtensionError.installReturnedNil
  //      }
  //
  //      switch result {
  //      case .completed:
  //        appLogger.info("System extension installed immediately.")
  //        return
  //      case .willCompleteAfterReboot:
  //        appLogger.error("System extension requires reboot to finish installation.")
  //        throw SystemExtensionError.requiresReboot
  //      @unknown default:
  //        // In case Apple adds new cases in the future
  //        appLogger.error(
  //          "SystemExtension.install returned unknown result: \(String(describing: result))")
  //        return
  //      }
  //    } catch {
  //      appLogger.error("System extension install threw error: \(error.localizedDescription)")
  //      throw error
  //    }
  //  }

}
