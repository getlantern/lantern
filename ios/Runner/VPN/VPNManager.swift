//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
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
    }
    appLogger.log("VPNManager initialized")
    Task {
      await restoreVPNStatus()
    }

  }

  //    Restores the VPN connection status from the system when the user closes the app without disconnecting VPN.
  func restoreVPNStatus() async {
    appLogger.log("Restoring VPN status...")
    
    do {
        let vpnManagerFound = await Profile.shared.vpnManagerExists()
        if( !vpnManagerFound) {
            appLogger.log("No existing VPN profile found during restore. must be first run.")
            return
        }
            
      guard let manager = await Profile.shared.getManager() else {
        let msg = "Unable to load or create VPN manager."
        appLogger.error(msg)
        throw NSError(
          domain: "VPNManagerError",
          code: 1003,
          userInfo: [NSLocalizedDescriptionKey: msg]
        )
      }
      let status = manager.connection.status
      appLogger.log("Restored VPN status: \(status.rawValue)")
      self.connectionStatus = status
    } catch {
      appLogger.error("Failed to restore VPN status: \(error.localizedDescription)")
    }
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
    guard connectionStatus == .disconnected else { return }
    appLogger.log("Starting tunnel..")
    guard let manager = await Profile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }

    let options: [String: NSObject] = [
      "netEx.Type": "Lantern" as NSString,
      "netEx.StartReason": "User Initiated" as NSString,
    ]

    if manager.connection.status == .connected || manager.connection.status == .connecting {
      appLogger.info("VPN is already connected, sending command to extension")
      do {
        let result = try await triggerExtensionMethod(methodName: "Lantern")
        return
      } catch {
        // Rethrow so caller can handle it
        throw error
      }
    }

    try manager.connection.startVPNTunnel(options: options)
    /// Enable on-demand to allow automatic reconnections
    /// this getting stuck in infinite loop
    //self.manager.isOnDemandEnabled = true
    // try await self.saveThenLoadProvider()
  }

  func connectToServer(
    location: String,
    serverName: String,
  ) async throws {
    guard let manager = await Profile.shared.getManager() else {
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

    if manager.connection.status == .connected || manager.connection.status == .connecting {
      appLogger.info("VPN is already connected, sending command to extension")
      do {
        let result = try await triggerExtensionMethod(
          methodName: "PrivateServer",
          params: ["server": serverName, "location": location]
        )
        return
      } catch {
        // Rethrow so caller can handle it
        throw error
      }
    }

    try manager.connection.startVPNTunnel(options: options)
    //    self.manager.isOnDemandEnabled = true
    //    try await self.saveThenLoadProvider()

  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    guard connectionStatus == .connected else { return }

    guard let manager = await Profile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }
    let startTime = Date()
    appLogger.log("Stopping tunnel..")

    manager.connection.stopVPNTunnel()
    manager.isOnDemandEnabled = false
    let elapsed = Date().timeIntervalSince(startTime)
    appLogger.log("Tunnel stopped successfully in \(elapsed) seconds")
  }

  /// MARK: - Extension Communication
  /// Triggers a method in the VPN extension and handles the response.
  func triggerExtensionMethod(
    methodName: String,
    params: [String: Any] = [:]
  ) async throws -> String {

    guard let manager = await Profile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      throw NSError(
        domain: "VPNManagerError",
        code: 1003,
        userInfo: [NSLocalizedDescriptionKey: msg]
      )
    }
    guard let session = manager.connection as? NETunnelProviderSession else {
      throw NSError(
        domain: "VPNManager", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Could not get tunnel session"])
    }

    let messageDict: [String: Any] = ["method": methodName, "params": params]
    let messageData = try JSONSerialization.data(withJSONObject: messageDict)

    return try await withCheckedThrowingContinuation { continuation in
      do {
        try session.sendProviderMessage(messageData) { responseData in
          guard let data = responseData else {
            return continuation.resume(
              throwing: NSError(
                domain: "VPNManager", code: -2,
                userInfo: [NSLocalizedDescriptionKey: "No response from provider"]))
          }

          if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let errorMsg = dict["error"] as? String
          {
            continuation.resume(
              throwing: NSError(
                domain: "VPNManager", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMsg]))
          } else if let result = String(data: data, encoding: .utf8) {
            continuation.resume(returning: result)
          } else {
            continuation.resume(
              throwing: NSError(
                domain: "VPNManager", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
          }
        }
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

}
