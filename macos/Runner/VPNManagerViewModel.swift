import NetworkExtension
//import SystemExtensions // For OSSystemExtensionRequest
import OSLog

class VPNManagerViewModel: ObservableObject {
    @Published var vpnStatus: NEVPNStatus = .invalid
    @Published var isVPNEnabled: Bool = false

    private var manager: NETunnelProviderManager?
    let logger = Logger(subsystem: "org.getlantern.lantern", category: "VPNManager")
    let providerBundleID = "org.getlantern.lantern.PacketTunnel"

    init() {
        
        Task {
            do {
                print("install started")
                await setupVPN()
                print("install finished")
                try? self.manager?.connection.startVPNTunnel()
                //startVPNTunnel()
                //print("started VPN tunnel")
            } catch {
                print("Async operation in Task failed: \(error)")
                // Handle error, potentially update UI on MainActor
            }
        }
        //loadManager()
         
        //savePreferencesAndEnable()
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
    /*
    private func loadManager(completion: (() -> Void)? = nil) {
        self.logger.log("Loading VPN preferences...")
        NETunnelProviderManager.loadAllFromPreferences { [weak self] (managers, error) in
            guard let self = self else {
                print("Not self")
                return
            }
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
                let manager = NETunnelProviderManager()
                manager.localizedDescription = "Lantern" // User-visible name in Network Preferences
                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.providerBundleIdentifier = self.providerBundleID
                tunnelProtocol.serverAddress = "sing-box"
                manager.protocolConfiguration = tunnelProtocol
                self.manager = manager
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
            //setupVPN { [weak self] in // Load first, then try again
             //   self?.savePreferencesAndEnable()
            //}
            return
        }

        logger.info(#function)
        // Create the protocol configuration if it doesn't exist or needs update
        //let protocolConfiguration = NETunnelProviderProtocol()
        //protocolConfiguration.providerBundleIdentifier = self.providerBundleID
        //protocolConfiguration.serverAddress = "sing-box"
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

        //manager.protocolConfiguration = protocolConfiguration
        //manager.localizedDescription = "Lantern" // User-visible name in Network Preferences
        //manager.isEnabled = true // This makes the configuration active
        manager.isEnabled = true
        manager.saveToPreferences { [weak self] error in
            guard let self = self else {
                print("Lantern could not save VPN preferences, self is nil")
                return
            }
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
     */
    

    /*
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
     */

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
    
    enum VPNLoadError: Error, LocalizedError {
        case noConfigurationsFound
        case multipleConfigurationsFound // If you expect only one
        case underlyingError(Error)

        var errorDescription: String? {
            switch self {
            case .noConfigurationsFound:
                return "No VPN configurations were found for this app."
            case .multipleConfigurationsFound:
                return "Multiple VPN configurations found. Please specify which one to use."
            case .underlyingError(let error):
                return "Failed to load VPN configurations: \(error.localizedDescription)"
            }
        }
    }

    func loadExistingVPNManager(targetLocalizedDescription: String? = nil) async -> Result<NETunnelProviderManager, VPNLoadError> {
        logger.info("Attempting to load VPN configurations...")
        do {
            let managers: [NETunnelProviderManager] = try await NETunnelProviderManager.loadAllFromPreferences()

            if managers.isEmpty {
                logger.notice("No VPN configurations found for this app.")
                return .failure(.noConfigurationsFound)
            }

            logger.info("Found \(managers.count) VPN configuration(s).")

            if let targetDesc = targetLocalizedDescription {
                // If a specific description is provided, try to find that manager
                if let specificManager = managers.first(where: { $0.localizedDescription == targetDesc }) {
                    logger.info("Found specific VPN configuration: \(targetDesc)")
                    return .success(specificManager)
                } else {
                    logger.warning("Specific VPN configuration '\(targetDesc)' not found among loaded managers.")
                    // Fallback or specific error handling if the target isn't found
                    // For this example, we'll treat it as if no *suitable* configuration was found.
                    // You might want a different error or to return all managers.
                    return .failure(.noConfigurationsFound) // Or a more specific error
                }
            } else {
                // If no specific description, and you expect only one, handle accordingly
                if managers.count == 1 {
                    logger.info("Successfully loaded a single VPN configuration.")
                    return .success(managers[0])
                } else {
                    // Handle multiple configurations if you don't have a specific one to look for.
                    // For this example, we'll return a failure, but you might want to
                    // let the user choose or use the first one by default.
                    logger.warning("Multiple VPN configurations found, but no specific target. Returning the first one.")
                    // Depending on your app's logic, you might pick the first, or error out.
                    // For robustness, if you don't expect multiple, it's better to clarify.
                    // If you *do* expect multiple and don't have a target, this isn't an error.
                    // For this example, let's assume for simplicity we prefer a single, non-targeted load.
                    if let firstManager = managers.first {
                        return .success(firstManager) // Or handle as an error if ambiguity is an issue
                    } else {
                        // This case should technically not be hit if managers.isEmpty was checked
                        return .failure(.noConfigurationsFound)
                    }
                }
            }
        } catch let error as NEVPNError where error.code == .configurationUnknown {
            // This specific error code might be relevant, though loadAllFromPreferences
            // typically returns an empty array rather than throwing this.
            // It's more common for loadFromPreferences(withId:)
            logger.notice("NEVPNError: Configuration not found.")
            return .failure(.noConfigurationsFound)
        } catch {
            logger.error("An unexpected error occurred while loading VPN configurations: \(error.localizedDescription)")
            return .failure(.underlyingError(error))
        }
    }

    // Example usage:
    func setupVPN(completion: (() -> Void)? = nil) async {
        let result = await loadExistingVPNManager(targetLocalizedDescription: "Lantern") // Optional: specify a profile name
        switch result {
        case .success(let manager):
            logger.log("Successfully loaded VPN manager: \(manager.localizedDescription ?? "N/A")")
            self.manager = manager
            // Now you can use the 'manager' object to:
            // 1. Check its connection status: manager.connection.status
            // 2. Start the VPN: try? manager.connection.startVPNTunnel()
            // 3. Stop the VPN: manager.connection.stopVPNTunnel()
            // 4. Modify and save its configuration (if needed):
            //    manager.protocolConfiguration = myNewProtocolConfig
            //    manager.isEnabled = true
            //    try? await manager.saveToPreferences()
            //    logger.log("Manager protocol: \(String(describing: manager.protocolConfiguration))")
        case .failure(let error):
            logger.error("VPN setup failed: \(error.localizedDescription)")
            // Handle the error, e.g., by creating a new profile or alerting the user.
            if case .noConfigurationsFound = error {
                createNewProfile()
                logger.log("Saving new profile to preferences..")
                try? await self.manager?.saveToPreferences()
                logger.log("Saved new profile to preferences.")
                await setupVPN()
            }
        }
    }
    
    private func createNewProfile() {
        logger.info(">>> createNewProfile")
        let manager = NETunnelProviderManager()
        manager.localizedDescription = "Lantern" // User-visible name in Network Preferences
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = self.providerBundleID
        tunnelProtocol.serverAddress = "sing-box"
        manager.protocolConfiguration = tunnelProtocol
        manager.isEnabled = true
        self.manager = manager
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
