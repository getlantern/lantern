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
    onSuccess: ((String) -> Void)? = nil,
    onError: ((Error) -> Void)? = nil
  ) async {

    guard let manager = await Profile.shared.getManager() else {
      let msg = "Unable to load or create VPN manager."
      appLogger.error(msg)
      onError?(
        NSError(
          domain: "VPNManagerError",
          code: 1003,
          userInfo: [NSLocalizedDescriptionKey: msg]
        ))
      return
    }
    guard let session = manager.connection as? NETunnelProviderSession else {
      let error = NSError(
        domain: "VPNManager", code: -1,
        userInfo: [NSLocalizedDescriptionKey: "Could not get tunnel session"])
      appLogger.error("triggerExtensionMethod failed: \(error.localizedDescription)")
      onError?(error)
      return
    }

    guard let messageData = methodName.data(using: .utf8) else {
      let error = NSError(
        domain: "VPNManager", code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Invalid method name encoding"])
      appLogger.error("Invalid method name encoding")
      onError?(error)
      return
    }

    do {
      try session.sendProviderMessage(messageData) { responseData in
        guard let data = responseData else {
          let error = NSError(
            domain: "VPNManager", code: -2,
            userInfo: [NSLocalizedDescriptionKey: "No response from provider"])
          appLogger.error("triggerExtensionMethod failed: \(error.localizedDescription)")
          onError?(error)
          return
        }

        // Try to parse the response as JSON
        do {
          if let responseDict = try JSONSerialization.jsonObject(with: data, options: [])
            as? [String: Any],
            let errorMessage = responseDict["error"] as? String
          {
            // If there's an "error" key, trigger the error callback
            let error = NSError(
              domain: "VPNManager", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            appLogger.error("Error from provider: \(errorMessage)")
            onError?(error)
          } else {
            // If no "error" key, it's a success
            if let result = String(data: data, encoding: .utf8) {
              appLogger.log("Extension replied: \(result)")
              onSuccess?(result)
            } else {
              let error = NSError(
                domain: "VPNManager", code: -4,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
              appLogger.error("Invalid response format")
              onError?(error)
            }
          }
        } catch {
          // If the response isn't a valid JSON, it's an error
          let parseError = NSError(
            domain: "VPNManager", code: -5,
            userInfo: [NSLocalizedDescriptionKey: "Failed to parse response as JSON"])
          appLogger.error("Failed to parse response: \(error.localizedDescription)")
          onError?(parseError)
        }
      }
    } catch {
      appLogger.error("triggerExtensionMethod exception: \(error.localizedDescription)")
      onError?(error)
    }
  }

}
