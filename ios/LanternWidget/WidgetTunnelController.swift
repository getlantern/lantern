//
//  WidgetTunnelController.swift
//  LanternWidget
//
//  Drives the tunnel straight from the widget process. Requires the
//  packet-tunnel-provider entitlement on the widget target; without it
//  loadAllFromPreferences returns nothing and every action throws.
//
//  Only the start/stop request lives here. Status is published by the tunnel
//  process (PacketTunnelProvider) so the widget stays correct regardless of
//  whether the app is running.
//

import Foundation
import NetworkExtension

enum WidgetTunnelError: LocalizedError {
  case profileNotFound

  var errorDescription: String? {
    switch self {
    case .profileNotFound:
      return "Open Lantern once to set up the VPN before using the widget."
    }
  }
}

enum WidgetTunnelController {
  /// The snapshot to render, corrected against the tunnel's real status.
  ///
  /// The store can go stale: the tunnel may be killed before it writes its
  /// final state, or the app can overwrite a newer "disconnected" with an
  /// older "disconnecting" it received late. NETunnelProviderManager is the
  /// source of truth, so reconcile at render time and repair the store
  /// without triggering another reload.
  static func reconciledState() async -> VPNWidgetState {
    let stored = VPNWidgetStore.load()
    guard let manager = try? await loadManager() else { return stored }
    let live = manager.connection.status.widgetStatus
    guard live != stored.status else { return stored }
    appLogger.info(
      "Widget reconciling stale status \(stored.status.rawValue) -> \(live.rawValue)")
    return VPNWidgetStore.update(reload: false) { $0.status = live }
  }

  static func perform(_ action: VPNWidgetAction) async throws {
    let manager = try await loadManager()
    let status = manager.connection.status
    appLogger.info("Widget action \(action.rawValue) with tunnel status \(status.rawValue)")

    switch action {
    case .toggle:
      switch status {
      case .connected, .connecting, .reasserting:
        stop(manager)
      case .disconnected, .invalid:
        try await start(manager)
      case .disconnecting:
        break
      @unknown default:
        break
      }
    case .connect:
      guard status == .disconnected || status == .invalid else { return }
      try await start(manager)
    case .disconnect:
      guard status != .disconnected && status != .invalid else { return }
      stop(manager)
    }
  }

  /// The profile the app created; the widget never creates one itself so the
  /// user always goes through the app's VPN permission prompt first.
  private static func loadManager() async throws -> NETunnelProviderManager {
    let managers = try await NETunnelProviderManager.loadAllFromPreferences()
    guard
      let manager = managers.first(where: { $0.localizedDescription == FilePath.vpnProfileName })
        ?? managers.first
    else {
      appLogger.error("Widget: no Lantern VPN profile found")
      throw WidgetTunnelError.profileNotFound
    }
    return manager
  }

  private static func start(_ manager: NETunnelProviderManager) async throws {
    if !manager.isEnabled {
      manager.isEnabled = true
      try await manager.saveToPreferences()
      try await manager.loadFromPreferences()
    }

    // Reconnect to whatever the user last chose in the app (see VPNManager),
    // using the same option keys ExtensionProvider.startTunnel expects.
    let state = VPNWidgetStore.load()
    var options: [String: NSObject] = [
      "netEx.Type": (state.isAutoServer ? "Lantern" : "PrivateServer") as NSString,
      "netEx.StartReason": "Widget" as NSString,
    ]
    if !state.isAutoServer {
      options["netEx.ServerName"] = state.serverName as NSString
    }

    try manager.connection.startVPNTunnel(options: options)
    VPNWidgetStore.setStatus(.connecting)
  }

  private static func stop(_ manager: NETunnelProviderManager) {
    manager.connection.stopVPNTunnel()
    VPNWidgetStore.setStatus(.disconnecting)
  }
}
