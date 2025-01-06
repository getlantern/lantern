//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
    private var vpnManager = NETunnelProviderManager()
    
    static let shared: VPNManager = VPNManager()
    
    var connectionStatus: NEVPNStatus = .disconnected {
      didSet {
        guard oldValue != connectionStatus else { return }
        didUpdateConnectionStatusCallback?(connectionStatus)
      }
    }
    
    /// Callback closure to notify about connection status updates.
    var didUpdateConnectionStatusCallback: ((NEVPNStatus) -> Void)?

    private func loadVPNPreferences() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let manager = managers.first {
                self.vpnManager = manager
                return
            }
            try await self.setupVPN()

        } catch (_) {

        }
    }
    
    // Sets up a new VPN configuration.
    private func setupVPN() async throws {
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
        tunnelProtocol.serverAddress = "0.0.0.0"
        
        vpnManager.protocolConfiguration = tunnelProtocol
        vpnManager.localizedDescription = "Lantern"
        vpnManager.isEnabled = true
        
        let alwaysConnectRule = NEOnDemandRuleConnect()
        vpnManager.onDemandRules = [alwaysConnectRule]

        vpnManager.isOnDemandEnabled = false
        try await vpnManager.saveToPreferences()
        try await vpnManager.loadFromPreferences()
    }
    
    // MARK: - VPN Control Methods

    /// Starts the VPN tunnel.
    /// Loads VPN preferences and initiates the VPN connection.
    func startTunnel() async throws {
        await self.loadVPNPreferences()
        let options = ["netEx.StartReason": NSString("User Initiated")]
            
        print("Starting tunnel..")
        try self.vpnManager.connection.startVPNTunnel(options: options)

        self.vpnManager.isOnDemandEnabled = true
        try await self.saveThenLoadProvider()
    }

    /// Stops the VPN tunnel.
    /// Terminates the VPN connection and updates the configuration.
    func stopTunnel() async throws {
        print("Stopping tunnel..")
        vpnManager.connection.stopVPNTunnel()
        self.vpnManager.isOnDemandEnabled = false
        try await self.saveThenLoadProvider()
    }

    /// Saves the current VPN configuration to preferences and reloads it.
    private func saveThenLoadProvider() async throws {
        try await self.vpnManager.saveToPreferences()
        try await self.vpnManager.loadFromPreferences()
    }
}
