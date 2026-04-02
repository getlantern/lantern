import AppKit
import CryptoKit
import Foundation
import SystemExtensions

class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

  static let shared = SystemExtensionManager()
  private let tunnelBundleID = "org.getlantern.lantern.PacketTunnel"
  private var requestContexts: [ObjectIdentifier: RequestContext] = [:]

  @Published private(set) var status: ExtensionStatus = .notInstalled

  public func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension newExtension: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    let existingDescriptor = SystemExtensionDescriptor(properties: existing)
    let newDescriptor = SystemExtensionDescriptor(properties: newExtension)

    if #available(macOS 12.0, *), existing.isAwaitingUserApproval {
      appLogger.info(
        "Replacing system extension awaiting approval: existing=\(existingDescriptor.debugSummary) new=\(newDescriptor.debugSummary)"
      )
      return .replace
    }

    if existingDescriptor.matches(newDescriptor) {
      appLogger.info(
        "Skipping replacement because installed system extension already matches bundled extension: \(existingDescriptor.debugSummary)"
      )
      return .cancel
    }

    let changeSummary = SystemExtensionReconciler.describeChange(
      current: existingDescriptor,
      desired: newDescriptor)
    appLogger.info(
      "Replacing system extension: existing=\(existingDescriptor.debugSummary) new=\(newDescriptor.debugSummary) change=\(changeSummary)"
    )
    return .replace
  }

  public func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    let context = clearRequestContext(for: request)
    appLogger.info(
      "System extension request finished: context=\(context?.logDescription ?? "unknown") result=\(result.logDescription)"
    )

    switch result {
    case .completed:
      guard let context else {
        submitPropertiesRequest(context: .inspectStatus)
        return
      }
      switch context {
      case .deactivateThenActivate(_, let activateAfter):
        if activateAfter {
          submitActivationRequest(reason: "activating bundled extension after removing mismatched version")
        } else {
          submitPropertiesRequest(context: .inspectStatus)
        }
      case .inspectStatus, .reconcile, .activate:
        submitPropertiesRequest(context: .inspectStatus)
      }
    case .willCompleteAfterReboot:
      let details = context?.rebootDetails ?? "system extension change will finish after reboot"
      updateStatus(.requiresReboot(details: details))
    @unknown default:
      updateStatus(.error("Unknown system extension result"))
    }
  }

  public func request(
    _ request: OSSystemExtensionRequest,
    didFailWithError error: Error
  ) {
    let context = clearRequestContext(for: request)
    let nsError = error as NSError

    if nsError.domain == OSSystemExtensionErrorDomain
      && (
        nsError.code == OSSystemExtensionError.requestCanceled.rawValue
          || nsError.code == OSSystemExtensionError.requestSuperseded.rawValue
      )
    {
      appLogger.info(
        "System extension request ended without applying changes: context=\(context?.logDescription ?? "unknown") error=\(nsError.localizedDescription)"
      )
      submitPropertiesRequest(context: .inspectStatus)
      return
    }

    appLogger.error(
      "System extension request failed: context=\(context?.logDescription ?? "unknown") error=\(nsError.localizedDescription)"
    )
    updateStatus(.error(nsError.localizedDescription))
  }

  public func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    let context = requestContext(for: request)
    appLogger.info(
      "System extension requires user approval: context=\(context?.logDescription ?? "unknown")"
    )
    updateStatus(.requiresApproval)
  }

  public func request(
    _ request: OSSystemExtensionRequest,
    foundProperties properties: [OSSystemExtensionProperties]
  ) {
    let context = clearRequestContext(for: request) ?? .inspectStatus
    let bundled = SystemExtensionDescriptor.bundled(bundleID: tunnelBundleID)
    let installed = properties.map(SystemExtensionDescriptor.init(properties:))
    let reconciliation = SystemExtensionReconciler.reconcile(bundled: bundled, installed: installed)

    appLogger.info(
      "System extension snapshot: context=\(context.logDescription) bundled=\(bundled?.debugSummary ?? "missing") installed=[\(installed.map { $0.debugSummary }.joined(separator: ", "))] status=\(reconciliation.status.logDescription) action=\(reconciliation.action.logDescription)"
    )

    updateStatus(reconciliation.status)

    guard context == .reconcile else {
      return
    }

    perform(reconciliation.action)
  }

  public func deactivateExtension(bundleID: String) {
    appLogger.info("Deactivating system extension with ID: \(bundleID)")
    submitDeactivationRequest(
      reason: "manual deactivation for \(bundleID)",
      activateAfter: false,
      bundleID: bundleID)
  }

  public func activateExtension() {
    appLogger.info("Reconciling bundled system extension for ID: \(tunnelBundleID)")
    submitPropertiesRequest(context: .reconcile)
  }

  public func deactivateExtension() {
    appLogger.info("Deactivating system extension with ID: \(tunnelBundleID)")
    submitDeactivationRequest(reason: "manual deactivation", activateAfter: false)
  }

  public func checkInstallationStatus() {
    appLogger.info("Checking and reconciling installation status for ID: \(tunnelBundleID)")
    submitPropertiesRequest(context: .reconcile)
  }

  private func submitPropertiesRequest(context: RequestContext) {
    let request = OSSystemExtensionRequest.propertiesRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    submit(request, context: context)
  }

  private func submitActivationRequest(reason: String) {
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: tunnelBundleID,
      queue: .main
    )
    submit(request, context: .activate(reason: reason))
  }

  private func submitDeactivationRequest(
    reason: String,
    activateAfter: Bool,
    bundleID: String? = nil
  ) {
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: bundleID ?? tunnelBundleID,
      queue: .main
    )
    submit(request, context: .deactivateThenActivate(reason: reason, activateAfter: activateAfter))
  }

  private func submit(_ request: OSSystemExtensionRequest, context: RequestContext) {
    request.delegate = self
    requestContexts[ObjectIdentifier(request)] = context
    appLogger.info("Submitting system extension request: \(context.logDescription)")
    OSSystemExtensionManager.shared.submitRequest(request)
  }

  private func requestContext(for request: OSSystemExtensionRequest) -> RequestContext? {
    requestContexts[ObjectIdentifier(request)]
  }

  @discardableResult
  private func clearRequestContext(for request: OSSystemExtensionRequest) -> RequestContext? {
    requestContexts.removeValue(forKey: ObjectIdentifier(request))
  }

  private func perform(_ action: SystemExtensionInstallAction) {
    switch action {
    case .none:
      return
    case .activate(let reason):
      updateStatus(.updatePending(details: reason))
      submitActivationRequest(reason: reason)
    case .deactivateThenActivate(let reason):
      updateStatus(.updatePending(details: reason))
      submitDeactivationRequest(reason: reason, activateAfter: true)
    }
  }

  private func updateStatus(_ newStatus: ExtensionStatus) {
    guard status != newStatus else {
      return
    }

    status = newStatus
    appLogger.info("System extension status updated: \(newStatus.logDescription)")
  }

  public func openPrivacyAndSecuritySettings() {
    appLogger.log("Opening Privacy & Security settings for user approval.")
    let generalSecurityPaneURL = URL(
      string: "x-apple.systempreferences:com.apple.preference.security"
    )

    if #available(macOS 15.0, *) {
      if let url = URL(
        string:
          "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.system_extension.network_extension.extension-point"
      ) {
        appLogger.log("Open macOS 15.0 extensions")
        NSWorkspace.shared.open(url)
      }
    } else if #available(macOS 13.0, *) {
      if let url = URL(
        string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"
      ) {
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

private enum RequestContext: Equatable {
  case inspectStatus
  case reconcile
  case activate(reason: String)
  case deactivateThenActivate(reason: String, activateAfter: Bool)

  var logDescription: String {
    switch self {
    case .inspectStatus:
      return "inspectStatus"
    case .reconcile:
      return "reconcile"
    case .activate(let reason):
      return "activate(\(reason))"
    case .deactivateThenActivate(let reason, let activateAfter):
      return "deactivate(\(reason), activateAfter=\(activateAfter))"
    }
  }

  var rebootDetails: String {
    switch self {
    case .inspectStatus:
      return "system extension status refresh will finish after reboot"
    case .reconcile:
      return "system extension reconciliation will finish after reboot"
    case .activate(let reason):
      return "system extension activation will finish after reboot (\(reason))"
    case .deactivateThenActivate(let reason, let activateAfter):
      if activateAfter {
        return "system extension replacement will finish after reboot (\(reason))"
      }
      return "system extension deactivation will finish after reboot (\(reason))"
    }
  }
}

internal enum SystemExtensionInstallAction: Equatable {
  case none
  case activate(reason: String)
  case deactivateThenActivate(reason: String)

  var logDescription: String {
    switch self {
    case .none:
      return "none"
    case .activate(let reason):
      return "activate(\(reason))"
    case .deactivateThenActivate(let reason):
      return "deactivateThenActivate(\(reason))"
    }
  }
}

internal struct SystemExtensionDescriptor: Equatable {
  let bundleIdentifier: String
  let bundleShortVersion: String?
  let bundleVersion: String?
  let buildNumber: Int?
  let contentHash: String?
  let isEnabled: Bool
  let isAwaitingUserApproval: Bool
  let isUninstalling: Bool
  let url: URL?

  init(
    bundleIdentifier: String,
    bundleShortVersion: String? = nil,
    bundleVersion: String? = nil,
    contentHash: String? = nil,
    isEnabled: Bool = false,
    isAwaitingUserApproval: Bool = false,
    isUninstalling: Bool = false,
    url: URL? = nil
  ) {
    self.bundleIdentifier = bundleIdentifier
    self.bundleShortVersion = bundleShortVersion
    self.bundleVersion = bundleVersion
    self.buildNumber = Self.buildInt(bundleVersion)
    self.contentHash = contentHash
    self.isEnabled = isEnabled
    self.isAwaitingUserApproval = isAwaitingUserApproval
    self.isUninstalling = isUninstalling
    self.url = url
  }

  init(properties: OSSystemExtensionProperties) {
    self.init(
      bundleIdentifier: properties.bundleIdentifier,
      bundleShortVersion: properties.bundleShortVersion,
      bundleVersion: properties.bundleVersion,
      contentHash: SystemExtensionBundleHasher.hashBundle(at: properties.url),
      isEnabled: properties.isEnabled,
      isAwaitingUserApproval: properties.isAwaitingUserApproval,
      isUninstalling: properties.isUninstalling,
      url: properties.url
    )
  }

  static func bundled(bundleID: String) -> SystemExtensionDescriptor? {
    guard
      let sysExtURL = Bundle.main.builtInPlugInsURL?
        .deletingLastPathComponent()
        .appendingPathComponent("Library/SystemExtensions", isDirectory: true)
    else {
      return nil
    }

    let fileManager = FileManager.default
    guard let items = try? fileManager.contentsOfDirectory(
      at: sysExtURL,
      includingPropertiesForKeys: nil,
      options: [])
    else {
      return nil
    }

    guard let url = items.first(where: { candidate in
      candidate.pathExtension == "systemextension"
        && (Bundle(url: candidate)?.bundleIdentifier == bundleID)
    }), let bundle = Bundle(url: url)
    else {
      return nil
    }

    let shortVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    let bundleVersion = bundle.infoDictionary?["CFBundleVersion"] as? String

    return SystemExtensionDescriptor(
      bundleIdentifier: bundleID,
      bundleShortVersion: shortVersion,
      bundleVersion: bundleVersion,
      contentHash: SystemExtensionBundleHasher.hashBundle(at: url),
      url: url
    )
  }

  var versionSummary: String {
    "\(bundleShortVersion ?? "?")/\(bundleVersion ?? "?")"
  }

  var hashSummary: String {
    guard let contentHash else {
      return "unknown"
    }
    return String(contentHash.prefix(12))
  }

  var debugSummary: String {
    var segments = ["\(versionSummary) hash=\(hashSummary)"]
    if isEnabled {
      segments.append("enabled")
    }
    if isAwaitingUserApproval {
      segments.append("awaitingApproval")
    }
    if isUninstalling {
      segments.append("uninstalling")
    }
    return segments.joined(separator: " ")
  }

  func matchesVersion(_ other: SystemExtensionDescriptor) -> Bool {
    bundleIdentifier == other.bundleIdentifier
      && bundleShortVersion == other.bundleShortVersion
      && bundleVersion == other.bundleVersion
  }

  func matchesContent(_ other: SystemExtensionDescriptor) -> Bool {
    guard let contentHash, let otherHash = other.contentHash else {
      return false
    }
    return contentHash == otherHash
  }

  func matches(_ other: SystemExtensionDescriptor) -> Bool {
    matchesVersion(other) && matchesContent(other)
  }

  private static func buildInt(_ value: String?) -> Int? {
    guard let value else {
      return nil
    }
    return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

internal enum SystemExtensionChangeKind: String, Equatable {
  case matched
  case install
  case upgrade
  case downgrade
  case contentChange
  case mismatch
}

internal struct SystemExtensionReconciliation: Equatable {
  let status: ExtensionStatus
  let action: SystemExtensionInstallAction
  let change: SystemExtensionChangeKind
}

internal enum SystemExtensionReconciler {
  static func reconcile(
    bundled: SystemExtensionDescriptor?,
    installed: [SystemExtensionDescriptor]
  ) -> SystemExtensionReconciliation {
    guard let bundled else {
      return SystemExtensionReconciliation(
        status: .error("Bundled system extension not found"),
        action: .none,
        change: .mismatch)
    }

    let enabled = installed.first(where: \.isEnabled)

    if let enabled, enabled.matches(bundled) {
      return SystemExtensionReconciliation(
        status: .activated,
        action: .none,
        change: .matched)
    }

    if installed.contains(where: \.isAwaitingUserApproval) {
      return SystemExtensionReconciliation(
        status: .requiresApproval,
        action: .none,
        change: enabled == nil ? .install : classifyChange(current: enabled, desired: bundled))
    }

    if installed.contains(where: \.isUninstalling) {
      return SystemExtensionReconciliation(
        status: .requiresReboot(details: "system extension changes are waiting on a reboot"),
        action: .none,
        change: enabled == nil ? .install : classifyChange(current: enabled, desired: bundled))
    }

    guard !installed.isEmpty else {
      return SystemExtensionReconciliation(
        status: .notInstalled,
        action: .activate(reason: "install bundled system extension"),
        change: .install)
    }

    guard let enabled else {
      return SystemExtensionReconciliation(
        status: .updatePending(details: "no enabled system extension matches the current app"),
        action: .activate(reason: "activate bundled system extension"),
        change: .install)
    }

    let change = classifyChange(current: enabled, desired: bundled)
    switch change {
    case .matched:
      return SystemExtensionReconciliation(status: .activated, action: .none, change: .matched)
    case .upgrade:
      return SystemExtensionReconciliation(
        status: .updatePending(details: "bundled system extension is newer than the active extension"),
        action: .activate(reason: "replace active system extension with bundled upgrade"),
        change: .upgrade)
    case .downgrade:
      return SystemExtensionReconciliation(
        status: .updatePending(details: "active system extension is newer than the current app"),
        action: .deactivateThenActivate(reason: "replace newer system extension with bundled downgrade"),
        change: .downgrade)
    case .contentChange:
      return SystemExtensionReconciliation(
        status: .updatePending(details: "active system extension contents differ from the bundled extension"),
        action: .deactivateThenActivate(reason: "reload same-version system extension with bundled contents"),
        change: .contentChange)
    case .install:
      return SystemExtensionReconciliation(
        status: .notInstalled,
        action: .activate(reason: "install bundled system extension"),
        change: .install)
    case .mismatch:
      return SystemExtensionReconciliation(
        status: .updatePending(details: "active system extension does not match the current app"),
        action: .deactivateThenActivate(reason: "refresh mismatched system extension"),
        change: .mismatch)
    }
  }

  static func classifyChange(
    current: SystemExtensionDescriptor?,
    desired: SystemExtensionDescriptor
  ) -> SystemExtensionChangeKind {
    guard let current else {
      return .install
    }

    if current.matches(desired) {
      return .matched
    }

    if current.matchesVersion(desired) {
      guard let currentHash = current.contentHash, let desiredHash = desired.contentHash else {
        return .mismatch
      }
      return currentHash == desiredHash ? .matched : .contentChange
    }

    if let currentBuild = current.buildNumber, let desiredBuild = desired.buildNumber {
      if currentBuild < desiredBuild {
        return .upgrade
      }
      if currentBuild > desiredBuild {
        return .downgrade
      }
    }

    return .mismatch
  }

  static func describeChange(
    current: SystemExtensionDescriptor?,
    desired: SystemExtensionDescriptor
  ) -> String {
    classifyChange(current: current, desired: desired).rawValue
  }
}

internal enum SystemExtensionBundleHasher {
  static func hashBundle(at url: URL) -> String? {
    let fileManager = FileManager.default
    guard let enumerator = fileManager.enumerator(
      at: url,
      includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
      options: [],
      errorHandler: nil)
    else {
      return nil
    }

    var fileURLs: [URL] = []
    for case let fileURL as URL in enumerator {
      fileURLs.append(fileURL)
    }

    fileURLs.sort {
      relativePath(for: $0, under: url) < relativePath(for: $1, under: url)
    }

    var hasher = SHA256()

    for fileURL in fileURLs {
      let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
      let relative = relativePath(for: fileURL, under: url)

      if values?.isSymbolicLink == true {
        guard let destination = try? fileManager.destinationOfSymbolicLink(atPath: fileURL.path) else {
          return nil
        }
        hasher.update(data: Data(relative.utf8))
        hasher.update(data: Data([0]))
        hasher.update(data: Data(destination.utf8))
        hasher.update(data: Data([0]))
        continue
      }

      guard values?.isRegularFile == true else {
        continue
      }

      guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]) else {
        return nil
      }

      hasher.update(data: Data(relative.utf8))
      hasher.update(data: Data([0]))
      hasher.update(data: data)
      hasher.update(data: Data([0]))
    }

    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private static func relativePath(for fileURL: URL, under rootURL: URL) -> String {
    let rootPath = rootURL.standardizedFileURL.path.hasSuffix("/")
      ? rootURL.standardizedFileURL.path
      : rootURL.standardizedFileURL.path + "/"
    let filePath = fileURL.standardizedFileURL.path
    if filePath.hasPrefix(rootPath) {
      return String(filePath.dropFirst(rootPath.count))
    }
    return filePath
  }
}

extension OSSystemExtensionRequest.Result {
  fileprivate var logDescription: String {
    switch self {
    case .completed:
      return "completed"
    case .willCompleteAfterReboot:
      return "willCompleteAfterReboot"
    @unknown default:
      return "unknown(\(rawValue))"
    }
  }
}

public enum ExtensionStatus: Equatable {
  case notInstalled
  case installed
  case requiresApproval
  case requiresReboot(details: String?)
  case uninstalling
  case updatePending(details: String)
  case error(String)
  case timedOut
  case activated
  case deactivated

  var code: String {
    switch self {
    case .notInstalled: return "notInstalled"
    case .installed: return "installed"
    case .requiresApproval: return "requiresApproval"
    case .requiresReboot: return "requiresReboot"
    case .uninstalling: return "uninstalling"
    case .updatePending: return "updatePending"
    case .error: return "error"
    case .timedOut: return "timedOut"
    case .activated: return "activated"
    case .deactivated: return "deactivated"
    }
  }

  var details: String? {
    switch self {
    case .requiresReboot(let details):
      return details
    case .updatePending(let details):
      return details
    case .error(let message):
      return message
    default:
      return nil
    }
  }

  var logDescription: String {
    if let details {
      return "\(code):\(details)"
    }
    return code
  }
}
