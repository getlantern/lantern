import AppKit
import Foundation
import SystemExtensions

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

  static let shared = SystemExtensionManager()
  private var tunnelBundleID = "org.getlantern.lantern.PacketTunnel"
  private var semaphore: DispatchSemaphore?
  private var currentRequest: OSSystemExtensionRequest?
  private var error: Error?
  private var result: OSSystemExtensionRequest.Result?
  private var properties: [OSSystemExtensionProperties]?
  private var approvalRequired = false
  @Published private(set) var status: String = ExtensionStatus.notInstalled.asString

  // MARK: - Replacement decision
  /// Called when an existing installed extension is detected and the system asks what to do.
  /// Returns `.replace` to replace installed extension with the bundled one, `.cancel` to skip.
  public func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension newExtension: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    appLogger.log("Deciding replacement action for system extension.")

    if #available(macOS 12.0, *) {
      if existing.isAwaitingUserApproval {
        return .replace
      }
    }

    // If bundle identifier and versions are identical, skip replacement
    if existing.bundleIdentifier == newExtension.bundleIdentifier
      && existing.bundleVersion == newExtension.bundleVersion
      && existing.bundleShortVersion == newExtension.bundleShortVersion
    {
      appLogger.info("Skip update system extension — same version.")
      return .cancel
    } else {
      appLogger.info("Update system extension — different version detected.")
      return .replace
    }
  }

  // Called when system extension request completes successfully.
  public func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    appLogger.log("System extension request finished with result: \(result)")
    self.result = result
    updateStatus(mapResult(result))
  }

  // Called when system extension request fails with an error.
  public func request(
    _ request: OSSystemExtensionRequest,
    didFailWithError error: Error
  ) {
    appLogger.error("System extension request failed with error: \(error.localizedDescription)")
    self.error = error
    updateStatus(.error(error.localizedDescription))
  }

  // Called when user approval is required for the system extension.
  // this has to be handled by prompting the user to approve in System Settings.
  public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    approvalRequired = true
    appLogger.info("System extension request needs user approval.")
  }

  public func request(
    _ request: OSSystemExtensionRequest,
    foundProperties properties: [OSSystemExtensionProperties]
  ) {
    appLogger.info("System extension properties found.")
    self.properties = properties
    updateStatus(mapProperties(properties))
  }

  /// Deactivate (uninstall) the extension by bundle identifier. Submits the request and returns immediately.
  public func deactivateExtension(bundleID: String) {
    appLogger.log("Attempting to deactivate system extension with ID: \(bundleID)")
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: bundleID,
      queue: .main
    )
    request.delegate = self
    self.currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  public func activateExtensionAndWait() {
    appLogger.info("Attempting to activate system extension with ID: \(tunnelBundleID)")
    resetState()
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)

  }

  public func deactivateExtensionAndWait() {
    appLogger.info("Attempting to deactivate system extension with ID: \(tunnelBundleID)")
    resetState()
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  public func checkInstallationStatus() {
    appLogger.info("Checking installation status for system extension with ID: \(tunnelBundleID)")
    resetState()
    let request = OSSystemExtensionRequest.propertiesRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)

  }

  // MARK: - Common Helpers

  private func resetState() {
    appLogger.info("Resetting internal state for new operation.")
    result = nil
    error = nil
    properties = nil
    semaphore = DispatchSemaphore(value: 0)
  }

  private func waitAndMap(timeout: TimeInterval) throws -> String {
    appLogger.info("Waiting for operation to complete with timeout: \(timeout) seconds.")
    guard let semaphore = semaphore else { return ExtensionStatus.error("Internal state").asString }

    let waitResult = semaphore.wait(timeout: .now() + timeout)
    if waitResult == .timedOut {
      appLogger.error("System Extension timed out after \(timeout) seconds.")
      return ExtensionStatus.timedOut.asString
    }

    if approvalRequired {
      appLogger.info("System Extension requires user approval.")
      return ExtensionStatus.requiresApproval.asString
    }

    if let error = error {
      appLogger.error("error: \(error.localizedDescription)")
      throw error
    }

    if let props = properties {
      appLogger.info("Checked properties of system extension.")
      return mapProperties(props).asString
    }

    if let result = result {
      appLogger.info("Mapping operation result")
      return mapResult(result).asString
    }

    return ExtensionStatus.error("Unknown state").asString
  }

  private func mapProperties(_ props: [OSSystemExtensionProperties]) -> ExtensionStatus {
    appLogger.info("Mapping system extension properties to status.")
    guard let p = props.first else { return .notInstalled }
    if #available(macOS 12.0, *) {
      if p.isAwaitingUserApproval { return .requiresApproval }
      if p.isUninstalling { return .uninstalling }
      return .installed
    } else {
      appLogger.info("macOS version does not support isAwaitingUserApproval check.")
      return p.isUninstalling ? .uninstalling : .installed
    }
  }

  private func mapResult(_ result: OSSystemExtensionRequest.Result) -> ExtensionStatus {
    appLogger.info("Mapping system extension request result to status.")
    switch result {
    case .completed: return .activated
    case .willCompleteAfterReboot: return .activated
    @unknown default: return .error("Unknown result")
    }
  }

  private func updateStatus(_ newStatus: ExtensionStatus, details: String? = nil) {
    let statusString = newStatus.asString
    self.status = statusString
    appLogger.info("System extension status updated: \(self.status)")
  }

  /// Opens the System Settings/Preferences pane for Privacy & Security.
  /// This is where the user will approve the extension.
  public func openPrivacyAndSecuritySettings() {
    appLogger.log("Opening Privacy & Security settings for user approval.")
    // This URL scheme attempts to open the System Extensions section directly if available.
    // Fallback to the general Security & Privacy pane.
    let generalSecurityPaneURL = URL(
      string: "x-apple.systempreferences:com.apple.preference.security")

    // macOS Sequoia (15.0), Ventura (13.0), and earlier all use different paths for allowing the extension
    // in system settings.
    // See https://gist.github.com/rmcdongit/f66ff91e0dad78d4d6346a75ded4b751
    if #available(macOS 15.0, *) {
      if let url = URL(
        string:
          "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.system_extension.network_extension.extension-point"
      ) {
        appLogger.log("Open macOS 15.0 extensions")
        NSWorkspace.shared.open(url)
      }
    } else if #available(macOS 13.0, *) {
      // For macOS 13 and later, "Privacy & Security"
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension")
      {  // Ideal but might not always work
        appLogger.log("Opening PrivacySecurity.extension URL")
        NSWorkspace.shared.open(url)
      } else if let url = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity")
      {
        appLogger.log("Opening PrivacySecurity URL")
        NSWorkspace.shared.open(url)
      } else if let fallbackUrl = generalSecurityPaneURL {
        appLogger.log("Falling back to general Security & Privacy pane.")
        NSWorkspace.shared.open(fallbackUrl)
      }
    } else {
      // For macOS versions prior to 13.0 (e.g., Monterey, Big Sur)
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SystemExtensions")
      {
        NSWorkspace.shared.open(url)
      } else if let fallbackUrl = generalSecurityPaneURL {
        NSWorkspace.shared.open(fallbackUrl)
      }
    }
  }
}

public enum ExtensionStatus: Equatable {
  case notInstalled
  case installed
  case requiresApproval
  case uninstalling
  case error(String)
  case timedOut
  case activated
  case deactivated

  var asString: String {
    switch self {
    case .notInstalled: return "notInstalled"
    case .installed: return "installed"
    case .requiresApproval: return "requiresApproval"
    case .uninstalling: return "uninstalling"
    case .error(let msg): return "error:\(msg)"
    case .timedOut: return "timedOut"
    case .activated: return "activated"
    case .deactivated: return "deactivated"
    }
  }
}
