import NetworkExtension
//import SystemExtensions // For OSSystemExtensionRequest
import OSLog

class VPNManagerViewModel: ObservableObject {
    @Published var vpnStatus: NEVPNStatus = .invalid
    @Published var isVPNEnabled: Bool = false

    private var manager: NETunnelProviderManager?
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "org.getlantern.lantern", category: "VPNManager")
    let providerBundleID = "org.getlantern.lantern.PacketTunnelSystemExtension"

    init() {
        /*
        Task {
            do {
                print("install started")
                try await install()
                print("install finished")
                //startVPNTunnel()
                //print("started VPN tunnel")
            } catch {
                print("Async operation in Task failed: \(error)")
                // Handle error, potentially update UI on MainActor
            }
        }
        //loadManager()
         */
        savePreferencesAndEnable()
        //startVPNTunnel()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func vpnStatusDidChange(_ notification: Notification?) {
        guard let connection = notification?.object as? NEVPNConnection else { return }
        self.vpnStatus = connection.status
        logger.log("VPN Status changed: \(self.vpnStatus.description)")
    }

    // MARK: - VPN Configuration and Control
    private func loadManager(completion: (() -> Void)? = nil) {
        self.logger.log("Loading VPN preferences logger...")
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("Failed to load VPN preferences: \(error.localizedDescription)")
                completion?()
                return
            }

            if let existingManager = managers?.first {
                self.manager = existingManager
                self.logger.log("Loaded existing VPN configuration: \(existingManager.localizedDescription ?? "No Name")")
            } else {
                self.logger.log("No existing VPN configuration found, creating a new one.")
                //let manager = NETunnelProviderManager()
                // Further setup for a new manager will be in savePreferences
            }
            self.isVPNEnabled = self.manager?.isEnabled ?? false
            if let connection = self.manager?.connection {
                self.vpnStatus = connection.status
            }
            completion?()
        }
    }

    func savePreferencesAndEnable() {
        guard let manager = self.manager else {
            logger.error("Manager not loaded, attempting to load/create.")
            install { [weak self] in // Load first, then try again
                self?.savePreferencesAndEnable()
            }
            return
        }

        logger.info(#function)
        // Create the protocol configuration if it doesn't exist or needs update
        let protocolConfiguration = NETunnelProviderProtocol()
        protocolConfiguration.providerBundleIdentifier = self.providerBundleID
        protocolConfiguration.serverAddress = "sing-box"
        //protocolConfiguration.providerBundleIdentifier = self.providerBundleID // Critical: Links to your Network Extension
        //protocolConfiguration.serverAddress = "your.vpn.server.com" // Can be a placeholder or actual
        // You can pass configuration to your provider via providerConfiguration dictionary
        /*
        protocolConfiguration.providerConfiguration = [
            "username": "testuser",
            "port": 12345
            // Add other serializable data your provider needs
        ]
         */

        manager.protocolConfiguration = protocolConfiguration
        //manager.localizedDescription = "Lantern" // User-visible name in Network Preferences
        //manager.isEnabled = true // This makes the configuration active

        manager.saveToPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("Failed to save VPN preferences: \(error.localizedDescription)")
                // Handle error (e.g., user denied permission, or entitlement issues)
            } else {
                self.logger.log("VPN preferences saved and enabled.")
                self.isVPNEnabled = true
                // Important: After saving, sometimes you need to reload to ensure the connection object is valid
                self.loadManager() {
                    self.logger.log("Reloaded manager after saving.")
                }
            }
        }
    }
    
    private func install(completion: (() -> Void)? = nil) {
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "Lantern"
        //let tunnelProtocol = NETunnelProviderProtocol()
        //tunnelProtocol.providerBundleIdentifier = self.providerBundleID
        //tunnelProtocol.serverAddress = "sing-box"
        //manager.protocolConfiguration = tunnelProtocol
        //manager.isEnabled = true
        self.manager = manager
        completion?()
        //try await manager.saveToPreferences()
    }
    

    func startVPNTunnel() {
        guard let manager = self.manager, manager.isEnabled else {
            logger.warning("VPN is not enabled or manager not loaded. Call savePreferencesAndEnable() first.")
            // Optionally, try to save and enable first
            savePreferencesAndEnable() // This is aggressive, consider UX
            return
        }

        // Ensure the app is in /Applications for System Extensions
        // You might want to add a check here in a real app.

        logger.log("Attempting to start VPN tunnel...")
        do {
            //try manager.connection.startVPNTunnel()
            try manager.connection.startVPNTunnel(options: [
                "username": NSString(string: NSUserName()),
            ])
            // Note: Success here means the system *attempted* to start.
            // Listen to NEVPNStatusDidChange for actual connection status.
        } catch let error as NSError {
            logger.error("Failed to start VPN tunnel: \(error.localizedDescription) (Code: \(error.code))")
            // Common errors:
            // NEVPNError.configurationInvalid / NEVPNError.configurationDisabled
            // NEVPNError.nesessionAlreadyStarted (if already connecting/connected)
        }
    }

    func stopVPNTunnel() {
        guard let manager = self.manager else {
            logger.warning("Manager not loaded.")
            return
        }
        logger.log("Attempting to stop VPN tunnel...")
        manager.connection.stopVPNTunnel()
    }

    func toggleVPNConnection() {
        if let connection = manager?.connection {
            if connection.status == .disconnected || connection.status == .invalid {
                startVPNTunnel()
            } else {
                stopVPNTunnel()
            }
        } else {
             // If manager or connection is nil, likely not configured/enabled yet
            savePreferencesAndEnable() // Attempt to set up and then user can try again
            logger.warning("VPN not configured. Please enable and try again.")
        }
    }

    func removeFromPreferences() {
        guard let manager = self.manager else { return }
        manager.removeFromPreferences { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.logger.error("Failed to remove VPN preferences: \(error.localizedDescription)")
            } else {
                self.logger.log("VPN preferences removed.")
                self.manager = nil // Clear the local manager instance
                self.isVPNEnabled = false
                self.vpnStatus = .invalid
            }
        }
    }
}

// Add a description to NEVPNStatus for easier logging/display
extension NEVPNStatus: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalid: return "Invalid"
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        case .reasserting: return "Reasserting"
        case .disconnecting: return "Disconnecting"
        @unknown default: return "Unknown"
        }
    }
}
