//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
  private var manager: NEVPNManager?  // = NEVPNManager.shared()
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

  private func removeExistingVPNProfiles() async {
    do {
      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
      for manager in managers {
        appLogger.log("Removing VPN configuration: \(manager.localizedDescription ?? "Unnamed")")
        try await manager.removeFromPreferences()
      }
    } catch {
      appLogger.error("Unable to remove VPN profile: \(error.localizedDescription)")
    }
  }

  private func setupVPN() async {
    do {
      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
      if let existing = managers.first {
        self.manager = existing
        appLogger.log("Found existing VPN manager")
      } else {
        appLogger.log("No VPN profiles found, creating new profile")
        createNewProfile()
        try await self.manager?.saveToPreferences()
        try await self.manager?.loadFromPreferences()
        appLogger.log("Created and loaded new VPN profile")
      }
    } catch {
      appLogger.error("Failed to set up VPN: \(error.localizedDescription)")
    }
  }

  // Sets up a new VPN configuration for Lantern.
  private func createNewProfile() {
    let manager = NETunnelProviderManager()
    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerBundleIdentifier = "org.getlantern.lantern.PacketTunnel"
    tunnelProtocol.serverAddress = "0.0.0.0"

    manager.protocolConfiguration = tunnelProtocol
    manager.localizedDescription = "Lantern"
    manager.isEnabled = true

    let alwaysConnectRule = NEOnDemandRuleConnect()
    manager.onDemandRules = [alwaysConnectRule]

    manager.isOnDemandEnabled = false
    self.manager = manager
  }

  // MARK: - VPN Control Methods

  /// Starts the VPN tunnel.
  /// Loads VPN preferences and initiates the VPN connection.
  func startTunnel() async throws {
    guard connectionStatus == .disconnected else {
      appLogger.log("In unexpected state: \(connectionStatus)")
      return
    }
    appLogger.log("Starting tunnel..")
    await removeExistingVPNProfiles()
    await self.setupVPN()
    let options = ["netEx.StartReason": NSString("User Initiated")]
    try self.manager?.connection.startVPNTunnel(options: options)

    self.manager?.isOnDemandEnabled = true
    try await self.saveThenLoadProvider()
  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    appLogger.log("Stopping tunnel..")
    guard connectionStatus == .connected else {
      appLogger.log("In unexpected state: \(connectionStatus)")
      return
    }

    if manager?.isOnDemandEnabled ?? false {
      appLogger.info("Turning off on demand..")
      manager?.isOnDemandEnabled = false
      try await manager?.saveToPreferences()
    }
    manager?.connection.stopVPNTunnel()
  }

  /// Saves the current VPN configuration to preferences and reloads it.
  private func saveThenLoadProvider() async throws {
    try await self.manager?.saveToPreferences()
    try await self.manager?.loadFromPreferences()
  }

  /// MARK: - Extension Communication
  /// Triggers a method in the VPN extension and handles the response.
  func triggerExtensionMethod(
    methodName: String,
    onSuccess: ((String) -> Void)? = nil,
    onError: ((Error) -> Void)? = nil
  ) {
    guard let session = self.manager?.connection as? NETunnelProviderSession else {
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
