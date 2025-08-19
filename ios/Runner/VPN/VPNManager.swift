//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
  private var manager: NEVPNManager = NETunnelProviderManager.shared()
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

  @MainActor
  func loadManager() async {
    do {
      // Load all VPN configurations from preferences
      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
      if let existing = managers.first {
        self.manager = existing
        appLogger.log("Found the manager")
      } else {
        appLogger.log("No VPN config found.")
      }
    } catch {
      appLogger.error("error while loading manager \(error)")
    }
  }

  private func loadVPNPreferences() async {
    do {
      // Check for manager is there is not then loadManager
      if self.manager == nil {
        try await self.loadManager()
      }
      try await self.setupVPN()
    } catch {
      appLogger.error("Error loading VPN preferences: \(error)")
    }
  }

  // Sets up a new VPN configuration for Lantern.
  private func setupVPN() async throws {
    do {
      let managers = self.manager
      let manager = NETunnelProviderManager()
      let tunnelProtocol = NETunnelProviderProtocol()
      tunnelProtocol.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
      tunnelProtocol.serverAddress = "0.0.0.0"

      manager.protocolConfiguration = tunnelProtocol
      manager.localizedDescription = "LanternVPN"
      manager.isEnabled = true

      let alwaysConnectRule = NEOnDemandRuleConnect()
      manager.onDemandRules = [alwaysConnectRule]

      manager.isOnDemandEnabled = false
      try await manager.saveToPreferences()
      try await manager.loadFromPreferences()
      self.manager = manager
    } catch {
      print(error.localizedDescription)
    }
  }

  // MARK: - VPN Control Methods

  /// Starts the VPN tunnel.
  /// Loads VPN preferences and initiates the VPN connection.
  func startTunnel() async throws {
    guard connectionStatus == .disconnected else { return }
    appLogger.log("Starting tunnel..")
    await self.loadVPNPreferences()
    let options: [String: NSObject] = [
      "netEx.Type": "Lantern" as NSString,
      "netEx.StartReason": "User Initiated" as NSString,
    ]
    try self.manager.connection.startVPNTunnel(options: options)
    /// Enable on-demand to allow automatic reconnections
    /// this getting stuck in infinite loop
    //self.manager.isOnDemandEnabled = true
    // try await self.saveThenLoadProvider()
  }

  func connectToServer(
    location: String,
    serverName: String,
  ) async throws {
    await self.loadVPNPreferences()
    let options: [String: NSObject] = [
      "netEx.Type": "PrivateServer" as NSString,
      "netEx.StartReason": "Private server Initiated" as NSString,
      "netEx.ServerName": serverName as NSString,
      "netEx.Location": location as NSString,
    ]

    try self.manager.connection.startVPNTunnel(options: options)
    //    self.manager.isOnDemandEnabled = true
    //    try await self.saveThenLoadProvider()

  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    let startTime = Date()
    appLogger.log("Stopping tunnel..")
    guard connectionStatus == .connected else { return }
    manager.connection.stopVPNTunnel()
    self.manager.isOnDemandEnabled = false
    try await self.saveThenLoadProvider()
    let elapsed = Date().timeIntervalSince(startTime)

    appLogger.log("Tunnel stopped successfully in \(elapsed) seconds")

  }

  /// Saves the current VPN configuration to preferences and reloads it.
  private func saveThenLoadProvider() async throws {
    try await self.manager.saveToPreferences()
    try await self.manager.loadFromPreferences()
  }

  /// MARK: - Extension Communication
  /// Triggers a method in the VPN extension and handles the response.
  func triggerExtensionMethod(
    methodName: String,
    onSuccess: ((String) -> Void)? = nil,
    onError: ((Error) -> Void)? = nil
  ) {
    guard let session = self.manager.connection as? NETunnelProviderSession else {
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
