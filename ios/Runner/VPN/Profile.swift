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
  
      do {
      // 2️⃣ Hit the preferences store just once
      let all = try await NETunnelProviderManager.loadAllFromPreferences()

      if let existingManager = all.first {
        try await existingManager.loadFromPreferences()

        if needsMigration(manager: existingManager) {
          appLogger.log("⚠️ Old VPN profile requires migration — removing old profile")
          try await existingManager.removeFromPreferences()
        } else {
          // ⚙️ Ensure it's enabled (user might have switched to another VPN)
          if !existingManager.isEnabled {
            appLogger.log("Manager found but disabled — re-enabling.")
            existingManager.isEnabled = true
            try await existingManager.saveToPreferences()
            try await existingManager.loadFromPreferences()
            appLogger.log("Enabled existing VPN profile.")
          }
          self.manager = existingManager
          return existingManager
        }
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

  func vpnManagerExists() async -> Bool {
    do {
      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
      return managers.first(where: { $0.localizedDescription == FilePath.vpnProfileName }) != nil
    } catch {
      appLogger.error("Error checking for existing VPN profiles: \(error.localizedDescription)")
      return false
    }

  }

  /// Creates a new NETunnelProviderManager with Lantern settings.
  private func createNewProfile() -> NETunnelProviderManager {
    let manager = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
    proto.serverAddress = "0.0.0.0"

    manager.protocolConfiguration = proto
    manager.localizedDescription = FilePath.vpnProfileName
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

  func needsMigration(manager: NETunnelProviderManager) -> Bool {

    // Example conditions for migration:
    // 1. VPN name changed (user may have old name)
    if manager.localizedDescription != "LanternVPN" {
      return true
    }
    return false
  }

}
