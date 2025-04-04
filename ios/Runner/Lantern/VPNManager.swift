//
//  VPNManager.swift
//  Lantern
//

import Combine
import Network
import NetworkExtension

class VPNManager: VPNBase {
    private var vpnManager = NETunnelProviderManager()
    private var observer: NSObjectProtocol?
    private var manager: NEVPNManager = NEVPNManager.shared()
    static let shared: VPNManager = VPNManager()
    
    @Published private(set) var connectionStatus: NEVPNStatus = .disconnected {
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
    
    init() {
        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: nil) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }
            self?.connectionStatus = connection.status
        }
    }

    deinit {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Sets up a new VPN configuration.
    private func setupVPN() async throws {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let manager = managers.first {
                self.manager = manager
                return
            }
            let manager = NETunnelProviderManager()
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
            tunnelProtocol.serverAddress = "0.0.0.0"
            
            manager.protocolConfiguration = tunnelProtocol
            manager.localizedDescription = "Lantern"
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
        print("Starting tunnel..")
        await self.loadVPNPreferences()
        let options = ["netEx.StartReason": NSString("User Initiated")]
        try self.vpnManager.connection.startVPNTunnel(options: options)

        self.vpnManager.isOnDemandEnabled = true
        try await self.saveThenLoadProvider()
    }

    /// Stops the VPN tunnel.
    /// Terminates the VPN connection and updates the configuration.
    func stopTunnel() async throws {
        print("Stopping tunnel..")
        guard connectionStatus == .connected else { return }
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
