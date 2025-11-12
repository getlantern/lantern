//
//  Profile.swift
//  Runner
//
//  Created by jigar fumakiya on 21/08/25.
//

import Foundation
import NetworkExtension

public class Profile {
  public static let shared = Profile()
  private(set) var manager: NETunnelProviderManager?

  /// Loads or creates the NETunnelProviderManager and caches it in-memory.
  /// Subsequent calls return immediately without touching disk.
  func getManager() async -> NETunnelProviderManager? {
    // 1️⃣ Return from cache if already set
    if let cached = self.manager {
      appLogger.log("Using cached VPN manager.")
      return cached
    }

    do {
      // 2️⃣ Hit the preferences store just once
      let all = try await NETunnelProviderManager.loadAllFromPreferences()

      if let existingManager = all.first(where: {
        $0.localizedDescription == "LanternVPN"
      }) {
        // Reload existing manager this needed when user switch from any other VPN app
        try await existingManager.loadFromPreferences()
        // ⚙️ Ensure it's enabled (user might have switched to another VPN)
        if !existingManager.isEnabled {
          appLogger.log("Manager found but disabled — re-enabling.")
          existingManager.isEnabled = true
          try await existingManager.saveToPreferences()
          try await existingManager.loadFromPreferences()
          appLogger.log("Enabled existing VPN profile.")
        } else {
          appLogger.log("Found and loaded enabled VPN profile.")
        }

        appLogger.log("Found existing VPN profile; using it.")
        return existingManager
      }

      let manager: NETunnelProviderManager
      appLogger.log("No VPN profiles found; creating new profile.")
      manager = createNewProfile()
      try await manager.saveToPreferences()
      try await manager.loadFromPreferences()
      // 3️⃣ Cache it and return
      self.manager = manager
      return manager
    } catch {
      appLogger.error("Failed to load or create VPN manager: \(error.localizedDescription)")
      return nil
    }
  }

  /// Creates a new NETunnelProviderManager with Lantern settings.
  private func createNewProfile() -> NETunnelProviderManager {
    let manager = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
    proto.serverAddress = "0.0.0.0"

    manager.protocolConfiguration = proto
    manager.localizedDescription = "LanternVPN"
    manager.isEnabled = true

    // Keep on-demand rules defined, but disabled by default
    let onDemandRule = NEOnDemandRuleConnect()
    manager.onDemandRules = [onDemandRule]
    manager.isOnDemandEnabled = false

    return manager
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

}
