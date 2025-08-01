//
//  ExtensionProfile.swift
//  Runner
//
//  Created by jigar fumakiya on 31/07/25.
//

import Foundation
import NetworkExtension

public class ExtensionProfile {
  public static let shared = ExtensionProfile()
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

      let manager: NETunnelProviderManager
      if let existing = all.first {
        appLogger.log("Found existing VPN manager.")
        manager = existing
      } else {
        appLogger.log("No VPN profiles found; creating new profile.")
        manager = createNewProfile()

        // Only save — no need to load back immediately
        try await manager.saveToPreferences()
      }

      // 3️⃣ Cache it and return
      self.manager = manager
      return manager

    } catch {
      appLogger.error("Failed to load or create VPN manager: \(error.localizedDescription)")
      return nil
    }
  }

  //  private func setupVPN() async {
  //    do {
  //      let managers = try await NETunnelProviderManager.loadAllFromPreferences()
  //      if let existing = managers.first {
  //        self.manager = existing
  //        appLogger.log("Found existing VPN manager")
  //      } else {
  //        appLogger.log("No VPN profiles found, creating new profile")
  //        createNewProfile()
  //          try await self.manager?.saveToPreferences()
  //        try await self.manager?.loadFromPreferences()
  //        appLogger.log("Created and loaded new VPN profile")
  //      }
  //    } catch {
  //      appLogger.error("Failed to set up VPN: \(error.localizedDescription)")
  //    }
  //  }

  /// Creates a new NETunnelProviderManager with Lantern settings.
  private func createNewProfile() -> NETunnelProviderManager {
    let manager = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = "org.getlantern.lantern.PacketTunnel"
    proto.serverAddress = "0.0.0.0"

    manager.protocolConfiguration = proto
    manager.localizedDescription = "Lantern"
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
