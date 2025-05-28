import SystemExtensions
import OSLog // For structured logging
import AppKit // For NSWorkspace to open System Settings

// Define a notification name to inform other parts of your app (e.g., UI)
extension Notification.Name {
    static let systemExtensionNeedsUserApproval = Notification.Name("org.getlantern.lantern.systemExtensionNeedsUserApproval")
    static let systemExtensionApproved = Notification.Name("org.getlantern.lantern.systemExtensionApproved")
    static let systemExtensionActivationFailed = Notification.Name("org.getlantern.lantern.systemExtensionActivationFailed")
    static let systemExtensionActivationSucceeded = Notification.Name("org.getlantern.lantern.systemExtensionActivationSucceeded")
    static let systemExtensionRebootRequired = Notification.Name("org.getlantern.lantern.systemExtensionRebootRequired")
}

// Your class that manages system extension requests
// This class should conform to OSSystemExtensionRequestDelegate
class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

    let logger = Logger(subsystem: "org.getlantern.lantern", category: "SystemExtensionManager")
    static let shared = SystemExtensionManager()
    private var currentRequest: OSSystemExtensionRequest?

    // MARK: - Public Methods

    /// Initiates the activation of a system extension.
    /// - Parameter bundleID: The bundle identifier of the system extension to activate.
    public func activateExtension(bundleID: String) {
        logger.log("Attempting to activate system extension with ID: \(bundleID)")
        let request = OSSystemExtensionRequest.activationRequest(
            forExtensionWithIdentifier: bundleID,
            queue: .main // Ensure delegate methods are called on the main queue for UI updates
        )
        request.delegate = self
        self.currentRequest = request // Keep a reference if needed
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Initiates the deactivation of a system extension.
    /// - Parameter bundleID: The bundle identifier of the system extension to deactivate.
    public func deactivateExtension(bundleID: String) {
        logger.log("Attempting to deactivate system extension with ID: \(bundleID)")
        let request = OSSystemExtensionRequest.deactivationRequest(
            forExtensionWithIdentifier: bundleID,
            queue: .main
        )
        request.delegate = self
        self.currentRequest = request
        OSSystemExtensionManager.shared.submitRequest(request)
    }

    /// Opens the System Settings/Preferences pane for Privacy & Security.
    /// This is where the user will approve the extension.
    public func openPrivacyAndSecuritySettings() {
        logger.log("Opening Privacy & Security settings for user approval.")
        // This URL scheme attempts to open the System Extensions section directly if available.
        // Fallback to the general Security & Privacy pane.
        let generalSecurityPaneURL = URL(string: "x-apple.systempreferences:com.apple.preference.security")
        
        // macOS Sequoia (15.0), Ventura (13.0), and earlier all use different paths for allowing the extension
        // in system settings.
        // See https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751
        if #available(macOS 15.0, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.system_extension.network_extension.extension-point") {
                logger.log("Open macOS 15.0 extensions")
                NSWorkspace.shared.open(url)
            }
        } else if #available(macOS 13.0, *) {
            // For macOS 13 and later, "Privacy & Security"
             if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension") { // Ideal but might not always work
                logger.log("Opening PrivacySecurity.extension URL")
                NSWorkspace.shared.open(url)
            } else if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity") {
                logger.log("Opening PrivacySecurity URL")
                NSWorkspace.shared.open(url)
            } else if let fallbackUrl = generalSecurityPaneURL {
                logger.log("Falling back to general Security & Privacy pane.")
                NSWorkspace.shared.open(fallbackUrl)
            }
        } else {
            // For macOS versions prior to 13.0 (e.g., Monterey, Big Sur)
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SystemExtensions") {
                NSWorkspace.shared.open(url)
            } else if let fallbackUrl = generalSecurityPaneURL {
                NSWorkspace.shared.open(fallbackUrl)
            }
        }
    }

    // MARK: - OSSystemExtensionRequestDelegate Methods

    /// **This is the key method for handling the user approval requirement.**
    /// It's called when macOS determines that the user must manually approve the extension.
    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        logger.log("System extension (ID: \(request.identifier)) requires user approval. The request is now pending user action.")

        // 1. Inform your application's UI.
        //    Post a notification that the UI can observe to display appropriate instructions.
        NotificationCenter.default.post(name: .systemExtensionNeedsUserApproval, object: request.identifier)

        // 2. Guide the user.
        //    Your UI should now instruct the user to:
        //    a. Open System Settings (or System Preferences).
        //    b. Navigate to "Privacy & Security" (or "Security & Privacy").
        //    c. Find the prompt related to your application/developer and click "Allow" or "Enable".
        //    You can provide a button in your UI that calls `openPrivacyAndSecuritySettings()`.

        // IMPORTANT:
        // - The activation request is PAUSED at this point.
        // - Your app CANNOT programmatically approve the extension.
        // - The request will only proceed (to `didFinishWithResult` or `didFailWithError`)
        //   AFTER the user takes action in System Settings or if the request times out/is cancelled.
        // - There isn't a direct callback immediately after the user clicks "Allow".
        //   The original request will eventually complete or fail.
    }

    /// Called when an existing extension needs to be replaced.
    func request(_ request: OSSystemExtensionRequest,
                 actionForReplacingExtension existing: OSSystemExtensionProperties,
                 withExtension newExtension: OSSystemExtensionProperties) -> OSSystemExtensionRequest.ReplacementAction {
        logger.log("Found existing system extension (ID: \(request.identifier), Version: \(existing.bundleVersion). New version is \(newExtension.bundleVersion).")

        // Add your logic here. For example, always replace:
        // You might want to compare versions:
        // let existingVersion = SemVer(existing.bundleShortVersion)
        // let newVersion = SemVer(newExtension.bundleShortVersion)
        // if newVersion > existingVersion {
        //    return .replace
        // } else {
        //    return .cancel // or .replace if reinstalling same version is desired
        // }
        return .replace
    }

    /// Called when the system extension request finishes successfully.
    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        logger.log("System extension request (ID: \(request.identifier) finished with result: \(String(describing: result)))")
        currentRequest = nil // Clear the stored request

        switch result {
        case .completed:
            logger.log("System extension (ID: \(request.identifier) activated/deactivated successfully.")
            NotificationCenter.default.post(name: .systemExtensionActivationSucceeded, object: request.identifier)
            // If this was an activation request, you can now assume the extension is active.
            // If it was a deactivation, it's now inactive.

        case .willCompleteAfterReboot:
            logger.log("System extension (ID: \(request.identifier) action will complete after reboot. User needs to be informed.")
            NotificationCenter.default.post(name: .systemExtensionRebootRequired, object: request.identifier)
            // Your UI should inform the user that a reboot is necessary.

        @unknown default:
            logger.log("System extension request (ID: \(request.identifier) finished with an unknown result: \(String(describing: result))")
            // Handle unexpected future cases.
            let errorInfo = ["message": "Unknown result from system extension request.", "identifier": request.identifier]
            NotificationCenter.default.post(name: .systemExtensionActivationFailed, object: request.identifier, userInfo: errorInfo)
        }
    }

    /// Called when the system extension request fails.
    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        logger.log("System extension request (ID: \(request.identifier)) failed with error: \(error.localizedDescription)")
        currentRequest = nil // Clear the stored request

        // Provide more specific error information if possible by casting to OSSystemExtensionError
        if let sysexError = error as? OSSystemExtensionError {
            switch sysexError.code {
            case .missingEntitlement:
                logger.log("Error: Missing entitlement for system extension operations.")
            case .unsupportedParentBundleLocation:
                logger.log("Error: App is in an unsupported location (e.g., /tmp, /var). Move to /Applications.")
            // Add other specific OSSystemExtensionError.Code cases as needed
            default:
                logger.log("System extension error code: \(sysexError.code.rawValue)")
            }
        }
        
        //let userInfo = ["error": error, "identifier": request.identifier]
        let userInfo = ["identifier": request.identifier]
        NotificationCenter.default.post(name: .systemExtensionActivationFailed, object: request.identifier, userInfo: userInfo)
        // Your UI should inform the user about the failure.
    }
}
