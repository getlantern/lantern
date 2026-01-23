import AppKit
import Foundation
import SystemExtensions

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

  static let shared = SystemExtensionManager()
  private var tunnelBundleID = "org.getlantern.lantern.PacketTunnel"
  private var approvalRequired = false

  @Published private(set) var status: String = ExtensionStatus.notInstalled.asString

  // Called when an existing installed extension is detected and the system asks what to do.
  // Returns `.replace` to replace installed extension with the bundled one, `.cancel` to skip.
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

  // Called when the extension request completes successfully.
  public func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    appLogger.log("System extension request finished with result: \(result)")
    updateStatus(mapResult(result))
  }

  // Called when the extension request fails.
  public func request(
    _ request: OSSystemExtensionRequest,
    didFailWithError error: Error
  ) {
    appLogger.error("System extension request failed: \(error.localizedDescription)")
    updateStatus(.error(error.localizedDescription))
  }

  // Called when user approval is required in System Settings.
  public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    approvalRequired = true
    appLogger.info("System extension requires user approval.")
    updateStatus(.requiresApproval)
  }

  // Called when extension properties are returned.
  public func request(
    _ request: OSSystemExtensionRequest,
    foundProperties properties: [OSSystemExtensionProperties]
  ) {
    appLogger.info("System extension properties found")
    updateStatus(mapProperties(properties))
  }

  // Deactivate the extension by bundle ID.
  public func deactivateExtension(bundleID: String) {
    appLogger.log("Deactivating system extension with ID: \(bundleID)")
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: bundleID,
      queue: .main
    )
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  // Activate the extension by bundle ID (status updates via [status]).
  public func activateExtension() {
    appLogger.info("Activating system extension with ID: \(tunnelBundleID)")
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  // Deactivate the extension by bundle ID (status updates via [status]).
  public func deactivateExtension() {
    appLogger.info("Deactivating system extension with ID: \(tunnelBundleID)")
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  // Check if the extension is installed and approved.
  // Updates will be sent via [status].
  public func checkInstallationStatus() {
    appLogger.info("Checking installation status for ID: \(tunnelBundleID)")
    let request = OSSystemExtensionRequest.propertiesRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  // MARK: - Helpers

  private func buildInt(_ s: String?) -> Int? {
    guard let s else { return nil }
    return Int(s.trimmingCharacters(in: .whitespacesAndNewlines))
  }

  private func fmt(_ p: OSSystemExtensionProperties?) -> String {
    guard let p else { return "nil" }
    return "\(p.bundleShortVersion ?? "?")/\(p.bundleVersion ?? "?")"
  }

  // Look inside the app bundle to find the version/build of the embedded system extension
  private func bundledExtensionBuildAndShort() -> (build: Int?, short: String?) {
    guard
      let sysExtURL = Bundle.main.builtInPlugInsURL?
        .deletingLastPathComponent()
        .appendingPathComponent("Library/SystemExtensions", isDirectory: true)
    else { return (nil, nil) }

    let fm = FileManager.default
    guard let items = try? fm.contentsOfDirectory(at: sysExtURL, includingPropertiesForKeys: nil)
    else {
      return (nil, nil)
    }

    let match = items.first { url in
      url.pathExtension == "systemextension"
        && (Bundle(url: url)?.bundleIdentifier == tunnelBundleID)
    }

    guard let url = match, let b = Bundle(url: url) else { return (nil, nil) }

    let short = b.infoDictionary?["CFBundleShortVersionString"] as? String
    let buildStr = b.infoDictionary?["CFBundleVersion"] as? String
    return (buildInt(buildStr), short)
  }

  // MARK: - Status Mapping

  private func mapProperties(_ props: [OSSystemExtensionProperties]) -> ExtensionStatus {
    guard !props.isEmpty else { return .notInstalled }

    if #available(macOS 12.0, *) {
      if props.contains(where: { $0.isAwaitingUserApproval }) {
        return .requiresApproval
      }
    }

    let enabled = props.first(where: { $0.isEnabled })
    let enabledBuild = enabled.flatMap { buildInt($0.bundleVersion) } ?? -1

    let uninstalling = props.filter { $0.isUninstalling }
    let nonUninstalling = props.filter { !$0.isUninstalling }

    let uninstallingMax = uninstalling.max {
      (buildInt($0.bundleVersion) ?? -1) < (buildInt($1.bundleVersion) ?? -1)
    }
    let uninstallingMaxBuild = buildInt(uninstallingMax?.bundleVersion) ?? -1

    // Highest build version
    let installedMax = nonUninstalling.max {
      (buildInt($0.bundleVersion) ?? -1) < (buildInt($1.bundleVersion) ?? -1)
    }
    let installedMaxBuild = buildInt(installedMax?.bundleVersion) ?? -1

    // Version/build shipped inside the app bundle
    let bundled = bundledExtensionBuildAndShort()
    let bundledBuild = bundled.build ?? -1
    let haveBundled = bundled.build != nil

    let desiredBuild: Int = {
      if haveBundled {
        return max(bundledBuild, installedMaxBuild)
      }
      return installedMaxBuild
    }()

    appLogger.info(
      "SysExt snapshot: enabled=\(fmt(enabled)) enabledBuild=\(enabledBuild) "
        + "installedMax=\(fmt(installedMax)) installedMaxBuild=\(installedMaxBuild) "
        + "uninstallingMax=\(fmt(uninstallingMax)) uninstallingMaxBuild=\(uninstallingMaxBuild) "
        + "bundled=\(bundled.short ?? "?")/\(bundled.build.map(String.init) ?? "?") desiredBuild=\(desiredBuild)"
    )

    if desiredBuild >= 0 && uninstallingMaxBuild == desiredBuild {
      return .requiresReboot
    }

    // If nothing is enabled but we can see candidates, explicitly surface updatePending
    guard let enabled else {
      if desiredBuild >= 0 {
        let desiredDesc =
          haveBundled
          ? "desired=\(bundled.short ?? "?")/\(desiredBuild)"
          : "desiredInstalledMax=\(fmt(installedMax))"
        return .updatePending(details: "noneEnabled \(desiredDesc)")
      }
      return .notInstalled
    }

    // If enabled is behind desired, we want the newer one to “win”:
    // - If the newer one is stuck uninstalling, require reboot
    // - Otherwise mark updatePending
    if desiredBuild > enabledBuild {
      if uninstallingMaxBuild == desiredBuild {
        return .requiresReboot
      }
      if haveBundled, bundledBuild == desiredBuild {
        return .updatePending(
          details: "enabled=\(fmt(enabled)) bundled=\(bundled.short ?? "?")/\(desiredBuild)")
      }
      return .updatePending(details: "enabled=\(fmt(enabled)) installedMax=\(fmt(installedMax))")
    }

    return .activated
  }

  private func mapResult(_ result: OSSystemExtensionRequest.Result) -> ExtensionStatus {
    appLogger.info("Mapping system extension request result to status.")
    switch result {
    case .completed:
      return .activated
    case .willCompleteAfterReboot:
      return .requiresReboot
    @unknown default:
      return .error("Unknown result")
    }
  }

  // MARK: - Common Helpers

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
      string: "x-apple.systempreferences:com.apple.preference.security"
    )

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
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
      ) {  // Ideal but might not always work
        appLogger.log("Opening PrivacySecurity.extension URL")
        NSWorkspace.shared.open(url)
      } else if let url = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity"
      ) {
        appLogger.log("Opening PrivacySecurity URL")
        NSWorkspace.shared.open(url)
      } else if let fallbackUrl = generalSecurityPaneURL {
        appLogger.log("Falling back to general Security & Privacy pane.")
        NSWorkspace.shared.open(fallbackUrl)
      }
    } else {
      // For macOS versions prior to 13.0 (e.g., Monterey, Big Sur)
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SystemExtensions"
      ) {
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
  case requiresReboot
  case uninstalling
  case updatePending(details: String)
  case error(String)
  case timedOut
  case activated
  case deactivated

  var asString: String {
    switch self {
    case .notInstalled: return "notInstalled"
    case .installed: return "installed"
    case .requiresApproval: return "requiresApproval"
    case .requiresReboot: return "requiresReboot"
    case .uninstalling: return "uninstalling"
    case .updatePending(let details): return "updatePending:\(details)"
    case .error(let msg): return "error:\(msg)"
    case .timedOut: return "timedOut"
    case .activated: return "activated"
    case .deactivated: return "deactivated"
    }
  }
}
