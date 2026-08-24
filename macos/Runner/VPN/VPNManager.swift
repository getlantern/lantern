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
      guard let existing = await firstLaunchableProfile(among: managers) else {
        // Nothing configured yet, or nothing this build can launch. Adopting an
        // unlaunchable profile here would be worse than adopting none: the stop
        // path reads this manager's status, and a stale profile reporting
        // .disconnected makes it skip tearing down the tunnel that is running.
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

  /// Removes every saved profile, attempting all of them even if one fails, and
  /// rethrows the first failure.
  ///
  /// A profile left behind is found again by the next `loadAllFromPreferences()`,
  /// so a partial clear is not a rebuild: the caller must not go on to create a
  /// replacement and report success while the unlaunchable profile is still there.
  private func removeExistingVPNProfiles(operationID: UInt) async throws {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    var firstFailure: Error?
    for manager in managers {
      // Re-checked per profile rather than once for the loop: each removal is a
      // separate await that can block, so a stop can land between two of them.
      // Cancellation wins over `firstFailure` — the next setup attempt retries
      // the removals, and continuing to delete profiles while teardown runs is
      // the thing being prevented.
      try await requireOperation(operationID)
      do {
        appLogger.log("Removing VPN configuration: \(manager.localizedDescription ?? "Unnamed")")
        try await manager.removeFromPreferences()
      } catch {
        appLogger.error("Unable to remove VPN profile: \(error.localizedDescription)")
        firstFailure = firstFailure ?? error
      }
    }
    if let firstFailure {
      throw firstFailure
    }
  }

  /// Ensures `manager` holds a profile this build can launch, rebuilding if none
  /// of the saved ones qualify.
  ///
  /// Throws rather than logging: every caller starts a tunnel immediately
  /// afterwards, and starting one against a profile we failed to repair or
  /// rebuild is the silent failure this whole path exists to prevent.
  ///
  /// `operationID` is re-checked immediately before every preference write —
  /// each `removeFromPreferences()` and the `saveToPreferences()` of a new
  /// profile — not once up front. Each of those is a separate await that can
  /// block on a system permission prompt, and `beginStopOperation()` waits only
  /// 5s for this operation to hand the manager back; past that a stop proceeds
  /// to teardown while this call is still running, so a canceled start must not
  /// still be removing profiles or saving new ones underneath it.
  private func setupVPN(operationID: UInt) async throws {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    if let reusable = await firstLaunchableProfile(among: managers) {
      try await repairProfile(reusable, operationID: operationID)
      // Adopted only once it is known good, so a concurrent stop never sees a
      // half-repaired manager.
      self.manager = reusable
      appLogger.log("Reusing existing VPN profile")
      return
    }
    if managers.isEmpty {
      appLogger.log("No VPN profiles found, creating new profile")
    } else {
      appLogger.log("No saved VPN profile is launchable by this build, rebuilding")
      try await removeExistingVPNProfiles(operationID: operationID)
    }
    let created = createNewProfile()
    try await requireOperation(operationID)
    try await created.saveToPreferences()
    try await created.loadFromPreferences()
    self.manager = created
    appLogger.log("Created and loaded new VPN profile")
  }

  /// Throws unless this operation still owns the VPN lifecycle.
  ///
  /// Ownership is lost when a stop is pending, and also when the stop handoff
  /// already expired and released `activeConnectionID` (`VPNBase.swift`,
  /// `expireStopHandoff`) — so this is broader than "a stop canceled us", and
  /// `.operationInProgress` is the same error the coordinator raises for any
  /// other lifecycle contention.
  private func requireOperation(_ operationID: UInt) async throws {
    guard await lifecycleCoordinator.canContinueConnectionOperation(operationID) else {
      throw VPNManagerError.operationInProgress
    }
  }

  /// Returns the first saved profile this build can actually launch.
  ///
  /// Each candidate is refreshed from preferences before it is inspected:
  /// `loadAllFromPreferences()` can hand back a manager whose configuration has
  /// not been faulted in, and validating unpopulated fields would reject a
  /// perfectly good profile.
  private func firstLaunchableProfile(
    among managers: [NETunnelProviderManager]
  ) async -> NETunnelProviderManager? {
    for candidate in managers {
      do {
        try await candidate.loadFromPreferences()
      } catch {
        // One unreadable profile must not hide a good one behind it, nor abort
        // setup into the rebuild path when a usable profile may still follow.
        appLogger.error(
          "Skipping unreadable VPN profile \(candidate.localizedDescription ?? "Unnamed"): \(error.localizedDescription)"
        )
        continue
      }
      let tunnelProtocol = candidate.protocolConfiguration as? NETunnelProviderProtocol
      guard
        let defect = vpnProfileDefect(
          isTunnelProfile: tunnelProtocol != nil,
          providerBundleID: tunnelProtocol?.providerBundleIdentifier
        )
      else {
        return candidate
      }
      appLogger.log(
        "Discarding VPN profile \(candidate.localizedDescription ?? "Unnamed"): \(defect)")
    }
    return nil
  }

  /// Applies the corrections a launchable profile needs before use.
  private func repairProfile(
    _ manager: NETunnelProviderManager,
    operationID: UInt
  ) async throws {
    let repairs = vpnProfileRepairs(
      currentName: manager.localizedDescription,
      isEnabled: manager.isEnabled
    )
    guard !repairs.isEmpty else { return }
    try await requireOperation(operationID)
    if let rename = repairs.rename {
      appLogger.log(
        "Renaming VPN profile \(manager.localizedDescription ?? "Unnamed") to \(rename)")
      manager.localizedDescription = rename
    }
    if repairs.enable {
      appLogger.log("VPN profile is disabled, re-enabling")
      manager.isEnabled = true
    }
    try await manager.saveToPreferences()
    try await manager.loadFromPreferences()
  }

  /// Builds a fresh VPN configuration for Lantern. The caller adopts it only
  /// after it has been saved and reloaded.
  private func createNewProfile() -> NETunnelProviderManager {
    let manager = NETunnelProviderManager()
    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerBundleIdentifier = VPNProfileIdentity.providerBundleID
    tunnelProtocol.serverAddress = "0.0.0.0"

    manager.protocolConfiguration = tunnelProtocol
    manager.localizedDescription = VPNProfileIdentity.name
    manager.isEnabled = true

    let alwaysConnectRule = NEOnDemandRuleConnect()
    manager.onDemandRules = [alwaysConnectRule]

    manager.isOnDemandEnabled = false
    return manager
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
    try await self.setupVPN(operationID: operationID)
    guard await lifecycleCoordinator.canContinueConnectionOperation(operationID) else {
      throw VPNManagerError.operationInProgress
    }
    appLogger.log("Calling manager.connection.startVPNTunnel..")

    if try shouldStartNewTunnel(for: manager.connection.status) {
      self.manager.isOnDemandEnabled = false
      try await self.saveThenLoadProvider()
    }

    try await startOrNotifyExistingTunnel(
      operationID: operationID,
      options: ["netEx.StartReason": NSString("Lantern")],
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
    try await self.setupVPN(operationID: operationID)
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
