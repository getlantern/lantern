//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
  //Do not switch to NEVPNManager.shared() that is only for class app extension
  private var manager: NEVPNManager = NETunnelProviderManager()
  private let tunnelBundleID = "org.getlantern.lantern.PacketTunnel"
  private let stopPollIntervalNanoseconds: UInt64 = 200_000_000
  private let stopTimeoutSeconds: TimeInterval = 8
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
    Task { await syncStatus() }
  }

  /// Loads an existing VPN profile from preferences and reads its current
  /// connection status. This ensures the in-memory state reflects the system
  /// state — for example when the VPN was connected via System Settings
  /// before the app launched.
  ///
  /// Unlike setupVPN(), this does NOT create a new profile if none exists,
  /// avoiding the system VPN permission prompt on first launch.
  func syncStatus() async {
    do {
      let managers = try await loadLanternVPNProfiles()
      guard let existing = managers.first else {
        // No VPN profile configured yet — nothing to sync.
        return
      }
      self.manager = existing
      let systemStatus = manager.connection.status
      if systemStatus != connectionStatus {
        appLogger.info("Syncing VPN status: \(connectionStatus) -> \(systemStatus)")
        connectionStatus = systemStatus
      }
    } catch {
      appLogger.error("Failed to sync VPN status: \(error.localizedDescription)")
    }
  }

  deinit {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  private func removeExistingVPNProfiles() async {
    do {
      let managers = try await loadLanternVPNProfiles()
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
      let managers = try await loadLanternVPNProfiles()
      if let existing = managers.first {
        self.manager = existing
        appLogger.log("Found existing VPN manager")
      } else {
        appLogger.log("No VPN profiles found, creating new profile")
        createNewProfile()
        try await self.manager.saveToPreferences()
        try await self.manager.loadFromPreferences()
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
    appLogger.log("Starting tunnel..")
    await self.setupVPN()
    let options = ["netEx.StartReason": NSString("Lantern")]
    appLogger.log("Calling manager.connection.startVPNTunnel..")

    if manager.connection.status == .connected || manager.connection.status == .connecting {
      appLogger.info("VPN is already connected, sending command to extension")
      do {
        let result = try await triggerExtensionMethod(
          methodName: "Lantern"
        )
        return
      } catch {
        // Rethrow so caller can handle it
        throw error
      }
    }

    try self.manager.connection.startVPNTunnel(options: options)
    self.manager.isOnDemandEnabled = false
    try await self.saveThenLoadProvider()
  }

  func connectToServer(
    serverName: String,
  ) async throws {
    await self.setupVPN()
    let options: [String: NSObject] = [
      "netEx.Type": "PrivateServer" as NSString,
      "netEx.StartReason": "Private server Initiated" as NSString,
      "netEx.ServerName": serverName as NSString,
    ]

    if manager.connection.status == .connected || manager.connection.status == .connecting {
      appLogger.info("VPN is already connected, sending command to extension")
      do {
        let result = try await triggerExtensionMethod(
          methodName: "PrivateServer",
          params: ["server": serverName]
        )
        return
      } catch {
        // Rethrow so caller can handle it
        throw error
      }
    }

    try self.manager.connection.startVPNTunnel(options: options)
    /// Enable on-demand to allow automatic reconnections
    /// if error it will stuck in infinite loop
    //    self.manager.isOnDemandEnabled = true
    //    try await self.saveThenLoadProvider()

  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    appLogger.log("Stopping tunnel..")
    let managers = try await loadLanternVPNProfiles()
    guard !managers.isEmpty else {
      await syncStatus()
      appLogger.log("No Lantern VPN profile found while stopping.")
      return
    }

    let primary = managers.first { !$0.connection.status.isTerminalForLanternStop } ?? managers[0]
    self.manager = primary
    connectionStatus = primary.connection.status

    for manager in managers {
      let status = manager.connection.status
      appLogger.info(
        "Considering Lantern VPN profile for stop: \(manager.localizedDescription ?? "Unnamed") status=\(status.logDescription)"
      )

      if manager.isOnDemandEnabled {
        appLogger.info("Turning off on demand..")
        manager.isOnDemandEnabled = false
        try await manager.saveToPreferences()
      }

      guard !status.isTerminalForLanternStop else {
        continue
      }

      if status.shouldRequestTunnelStop {
        manager.connection.stopVPNTunnel()
      } else {
        appLogger.info("Tunnel already stopping; waiting for status to settle.")
      }
    }

    await waitForTunnelToStop(managers)
  }

  /// Saves the current VPN configuration to preferences and reloads it.
  private func saveThenLoadProvider() async throws {
    try await self.manager.saveToPreferences()
    try await self.manager.loadFromPreferences()
  }

  private func loadLanternVPNProfiles() async throws -> [NETunnelProviderManager] {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    return managers.filter { manager in
      guard let tunnelProtocol = manager.protocolConfiguration as? NETunnelProviderProtocol else {
        return false
      }
      return tunnelProtocol.providerBundleIdentifier == tunnelBundleID
    }
  }

  private func waitForTunnelToStop(_ managers: [NETunnelProviderManager]) async {
    let deadline = Date().addingTimeInterval(stopTimeoutSeconds)

    while Date() < deadline {
      let activeManagers = managers.filter { !$0.connection.status.isTerminalForLanternStop }
      if activeManagers.isEmpty {
        connectionStatus = manager.connection.status
        appLogger.log("Tunnel stopped.")
        return
      }

      connectionStatus = manager.connection.status
      try? await Task.sleep(nanoseconds: stopPollIntervalNanoseconds)
    }

    connectionStatus = manager.connection.status
    let statuses = managers
      .map { "\($0.localizedDescription ?? "Unnamed")=\($0.connection.status.logDescription)" }
      .joined(separator: ", ")
    appLogger.error("Timed out waiting for Lantern VPN tunnel to stop. statuses=[\(statuses)]")
  }

  /// MARK: - Extension Communication
  /// Triggers a method in the VPN extension and handles the response.
  func triggerExtensionMethod(
    methodName: String,
    params: [String: Any] = [:]
  ) async throws -> String {
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

private extension NEVPNStatus {
  var isTerminalForLanternStop: Bool {
    switch self {
    case .invalid, .disconnected:
      return true
    case .connecting, .connected, .reasserting, .disconnecting:
      return false
    @unknown default:
      return false
    }
  }

  var shouldRequestTunnelStop: Bool {
    switch self {
    case .connecting, .connected, .reasserting:
      return true
    case .invalid, .disconnected, .disconnecting:
      return false
    @unknown default:
      return true
    }
  }

  var logDescription: String {
    switch self {
    case .invalid:
      return "invalid"
    case .disconnected:
      return "disconnected"
    case .connecting:
      return "connecting"
    case .connected:
      return "connected"
    case .reasserting:
      return "reasserting"
    case .disconnecting:
      return "disconnecting"
    @unknown default:
      return "unknown(\(rawValue))"
    }
  }
}
