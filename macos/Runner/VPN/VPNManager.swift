//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
  private var observer: NSObjectProtocol?
  private let lifecycleCoordinator = VPNLifecycleCoordinator()
  //Do not switch to NEVPNManager.shared() that is only for class app extension
  private var manager: NEVPNManager = NETunnelProviderManager()
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
      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
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
    try await withConnectionOperation { operationID in
      try await startTunnel(operationID: operationID)
    }
  }

  private func startTunnel(operationID: UInt) async throws {
    appLogger.log("Starting tunnel..")
    await self.setupVPN()
    guard await lifecycleCoordinator.canContinueConnectionOperation(operationID) else {
      throw VPNManagerError.operationInProgress
    }
    let options = ["netEx.StartReason": NSString("Lantern")]
    appLogger.log("Calling manager.connection.startVPNTunnel..")

    if try !shouldStartNewTunnel(for: manager.connection.status) {
      appLogger.info("VPN is already connected, sending command to extension")
      _ = try await triggerExtensionMethod(methodName: "Lantern")
      return
    }

    self.manager.isOnDemandEnabled = false
    try await self.saveThenLoadProvider()
    try await startOrNotifyExistingTunnel(
      operationID: operationID,
      options: options,
      methodName: "Lantern"
    )
  }

  func connectToServer(
    serverName: String
  ) async throws {
    try await withConnectionOperation { operationID in
      try await connectToServer(serverName: serverName, operationID: operationID)
    }
  }

  private func connectToServer(serverName: String, operationID: UInt) async throws {
    await self.setupVPN()
    guard await lifecycleCoordinator.canContinueConnectionOperation(operationID) else {
      throw VPNManagerError.operationInProgress
    }
    let options: [String: NSObject] = [
      "netEx.Type": "PrivateServer" as NSString,
      "netEx.StartReason": "Private server Initiated" as NSString,
      "netEx.ServerName": serverName as NSString,
    ]

    try await startOrNotifyExistingTunnel(
      operationID: operationID,
      options: options,
      methodName: "PrivateServer",
      params: ["server": serverName]
    )
  }

  private func startOrNotifyExistingTunnel(
    operationID: UInt,
    options: [String: NSObject],
    methodName: String,
    params: [String: Any] = [:]
  ) async throws {
    let startedNewTunnel = try await lifecycleCoordinator.performFinalConnectionTransition(
      operationID
    ) {
      if try !shouldStartNewTunnel(for: self.manager.connection.status) {
        return false
      }
      try self.manager.connection.startVPNTunnel(options: options)
      return true
    }
    if !startedNewTunnel {
      appLogger.info("VPN is already connected, sending command to extension")
      _ = try await triggerExtensionMethod(methodName: methodName, params: params)
    }
  }

  /// Stops the VPN tunnel.
  /// Terminates the VPN connection and updates the configuration.
  func stopTunnel() async throws {
    let canceledConnectionOperation = try await lifecycleCoordinator.beginStopOperation()
    do {
      try await stopTunnelAfterHandoff(
        canceledConnectionOperation: canceledConnectionOperation)
    } catch {
      await lifecycleCoordinator.endStopOperation()
      throw error
    }
    await lifecycleCoordinator.endStopOperation()
  }

  private func stopTunnelAfterHandoff(canceledConnectionOperation: Bool) async throws {
    appLogger.log("Stopping tunnel..")

    // A canceled start already owns the current manager. Stop it before any
    // preference call can delay teardown again.
    if canceledConnectionOperation {
      let shouldSaveOnDemandChange = manager.isOnDemandEnabled
      manager.isOnDemandEnabled = false
      manager.connection.stopVPNTunnel()
      if shouldSaveOnDemandChange {
        try await manager.saveToPreferences()
      }
      appLogger.log("Tunnel stopped.")
      return
    }

    await syncStatus()
    let status = manager.connection.status
    let shouldStop = try shouldStopTunnel(for: status)
    if !shouldStop {
      appLogger.log("VPN is already stopped or stopping: \(status)")
      return
    }

    if manager.isOnDemandEnabled {
      appLogger.info("Turning off on demand..")
      manager.isOnDemandEnabled = false
      try await manager.saveToPreferences()
    }
    manager.connection.stopVPNTunnel()
    appLogger.log("Tunnel stopped.")
  }

  private func withConnectionOperation<T>(
    _ operation: (UInt) async throws -> T
  ) async throws -> T {
    let operationID = try await lifecycleCoordinator.beginConnectionOperation()
    do {
      let result = try await operation(operationID)
      await lifecycleCoordinator.endConnectionOperation(operationID)
      return result
    } catch {
      await lifecycleCoordinator.endConnectionOperation(operationID)
      throw error
    }
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
