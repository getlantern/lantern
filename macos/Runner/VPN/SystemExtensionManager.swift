import AppKit  // For NSWorkspace to open System Settings
import Foundation
import OSLog  // For structured logging
import SystemExtensions

/// Manages System Extension requests for the Tunnel extension.
/// NOTE: This implementation uses `DispatchSemaphore` to wait for OS callbacks,
/// which blocks the calling thread until the OS responds. Do NOT call the
/// blocking methods from the main thread — call from a background queue or wrapped
/// in a Task/Detached Task.
class SystemExtensionManager: NSObject, OSSystemExtensionRequestDelegate {

  /// Tunnel bundle identifier used by activation/deactivation by default.
  static let tunnelBundleID = "org.getlantern.lantern.PacketTunnel"

  static let shared = SystemExtensionManager()

  /// A semaphore used to block until the system invokes delegate callbacks.
  /// Re-created per call (if you plan to allow concurrent requests, move to per-request semaphores).
  private var semaphore: DispatchSemaphore?

  /// Currently active request (kept for debugging / cancellation intent).
  private var currentRequest: OSSystemExtensionRequest?

  /// Last error returned from `didFailWithError`.
  private var error: Error?

  /// Last result returned from `didFinishWithResult`.
  private var result: OSSystemExtensionRequest.Result?

  /// Last properties returned from a propertiesRequest.
  private var properties: [OSSystemExtensionProperties]?

  private override init() {
    super.init()
  }

  // MARK: - Replacement decision

  /// Called by the system when it discovers an existing installed extension that may be replaced.
  ///
  /// - Parameters:
  ///   - request: The incoming OSSystemExtensionRequest
  ///   - existing: The currently installed extension properties
  ///   - newExtension: The properties of the candidate extension (the one bundled with your app)
  /// - Returns: `.replace` to replace the existing extension with the new one, `.cancel` to skip replacement.
  func request(
    _ request: OSSystemExtensionRequest,
    actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension newExtension: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {

    // Use extensionIdentifier if available for logging; fall back to known tunnelBundleID.
    let extID = SystemExtensionManager.tunnelBundleID
      appLogger.log(
      "Found existing system extension (ID: \(extID), ExistingVersion: \(existing.bundleVersion), NewVersion: \(newExtension.bundleVersion))."
    )

    // If we want to force update, always replace
    // (You previously requested forceUpdate in other iterations — keep that policy if needed)
    // Example placeholder check (remove/replace with your own forceUpdate logic if available):
    // if forceUpdate { return .replace }

    if #available(macOS 12.0, *) {
      // If existing copy is awaiting user approval, prefer to replace so the bundled version is used once approved.
      if existing.isAwaitingUserApproval {
        return .replace
      }
    }

    // If bundle identifier and versions are identical, skip; otherwise replace.
    if existing.bundleIdentifier == newExtension.bundleIdentifier,
      existing.bundleVersion == newExtension.bundleVersion,
      existing.bundleShortVersion == newExtension.bundleShortVersion
    {
      appLogger.info("Skip update system extension — same version.")
      return .cancel
    } else {
      appLogger.info("Update system extension — different version detected.")
      return .replace
    }
  }

  // MARK: - OSSystemExtensionRequestDelegate Methods

  /// Called when macOS requires the user to approve the request manually in System Preferences.
  /// We signal the waiting semaphore so the caller can react (e.g., show UI instructing the user).
  func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
    let extID =  SystemExtensionManager.tunnelBundleID
      appLogger.log(
      "System extension (ID: \(extID)) requires user approval. The request is now pending user action."
    )
    // Release the semaphore so the caller can handle the state (user approval required).
    semaphore?.signal()
  }

  /// Called when a request finished with an OS-provided result (.completed, .willCompleteAfterReboot, etc.).
  func request(
    _ request: OSSystemExtensionRequest,
    didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    let extID =  SystemExtensionManager.tunnelBundleID
      appLogger.log(
      "System extension request (ID: \(extID)) finished with result: \(String(describing: result))"
    )
    self.result = result
    // Clear the current request reference (we are done)
    self.currentRequest = nil
    semaphore?.signal()
  }

  /// Called when the request fails with an error.
  func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
      appLogger.log(
        "System extension request (ID: \(SystemExtensionManager.tunnelBundleID)) failed with error: \(error.localizedDescription)"
    )
    currentRequest = nil  // Clear the stored request
    self.error = error
    appLogger.info(
      "Failed to activate: \(error.localizedDescription), code: \((error as NSError).code)")
    semaphore?.signal()
  }

  /// Called when properties for the extension are returned in response to a propertiesRequest.
  public func request(
    _ request: OSSystemExtensionRequest,
    foundProperties properties: [OSSystemExtensionProperties]
  ) {
    self.properties = properties
    semaphore?.signal()
  }

  // MARK: - Activation / Deactivation (non-blocking submit, blocking wait omitted in activateExtension)

  /// Submits an activation request for the configured tunnel bundle identifier.
  /// This method only submits — it does NOT wait. If you want to wait synchronously,
  /// call `activateExtensionAndWait(timeout:)`.
  public func activateExtension() {
      appLogger.log(
      "Attempting to activate system extension with ID: \(SystemExtensionManager.tunnelBundleID)")
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: SystemExtensionManager.tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    self.currentRequest = request  // Keep a reference if needed
    OSSystemExtensionManager.shared.submitRequest(request)
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

  // MARK: - Synchronous helpers (blocking) — call from background thread

  /// Activate and wait for the OS result or user approval/failure. Blocks the calling thread until callback or timeout.
  /// - Parameters:
  ///   - timeout: maximum wait time (seconds) before returning `nil` (timed out)
  /// - Returns: OSSystemExtensionRequest.Result if available; `nil` on timeout or if none returned.
  /// - Warning: Blocking — do NOT call from main thread.
  public func activateExtensionAndWait(timeout: TimeInterval = 30) -> OSSystemExtensionRequest
    .Result?
  {
    // reset previous state
    self.result = nil
    self.error = nil
    self.semaphore = DispatchSemaphore(value: 0)

    activateExtension()

    let waitResult = semaphore?.wait(timeout: .now() + timeout)
    // If timed out, return nil and preserve error/result for caller inspection
    if waitResult == .timedOut {
      appLogger.info("Activation timed out after \(timeout) seconds.")
      return nil
    }
    return result
  }

  /// Deactivate and wait synchronously for the OS result or error.
  /// - Warning: Blocking — do NOT call from main thread.
  public func deactivateExtensionAndWait(timeout: TimeInterval = 30) -> OSSystemExtensionRequest
    .Result?
  {
    self.result = nil
    self.error = nil
    self.semaphore = DispatchSemaphore(value: 0)

    // Use the known tunnel id, or change to accept a parameter if you want.
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: SystemExtensionManager.tunnelBundleID,
      queue: .main
    )
    request.delegate = self
    self.currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)

    let waitResult = semaphore?.wait(timeout: .now() + timeout)
    if waitResult == .timedOut {
      appLogger.info("Deactivation timed out after \(timeout) seconds.")
      return nil
    }
    return result
  }

  // MARK: - Check installation status

  /// Checks whether the system extension with the given bundle identifier is installed and active.
  ///
  /// Implementation:
  /// - submits a `propertiesRequest`
  /// - waits (blocking) for the OS response up to `timeout`
  /// - considers the extension installed when the returned properties array contains at least
  ///   one `OSSystemExtensionProperties` where `isAwaitingUserApproval` is false (on macOS 12+)
  ///   and `isUninstalling` is false.
  ///
  /// - Parameters:
  ///   - bundleID: the extension bundle identifier to check (default: `tunnelBundleID`)
  ///   - timeout: how long to wait for a response (seconds). Default 10s.
  /// - Returns: `true` if installed and not in uninstalling/awaiting-approval state, otherwise `false`.
  /// - Warning: Blocking — do NOT call from main thread.
  public func isInstalled(
    bundleID: String = SystemExtensionManager.tunnelBundleID,
    timeout: TimeInterval = 10
  ) -> Bool {
    // Reset state
    self.properties = nil
    self.error = nil
    self.semaphore = DispatchSemaphore(value: 0)

    let request = OSSystemExtensionRequest.propertiesRequest(
      forExtensionWithIdentifier: bundleID,
      queue: .main
    )
    request.delegate = self
    self.currentRequest = request
    OSSystemExtensionManager.shared.submitRequest(request)

    let waitResult = semaphore?.wait(timeout: .now() + timeout)
    if waitResult == .timedOut {
      appLogger.info("propertiesRequest timed out after \(timeout) seconds for \(bundleID)")
      return false
    }

    // If there was an error reported by delegate, treat as not installed.
    if error != nil {
      appLogger.error("Error while checking installation status: \(error!.localizedDescription)")
      return false
    }

    guard let props = properties, !props.isEmpty else {
      return false
    }

    for p in props {
      if #available(macOS 12.0, *) {
        // Consider installed only if not awaiting approval and not uninstalling
        if !p.isAwaitingUserApproval && !p.isUninstalling {
          return true
        }
      } else {
        // Prior to macOS 12 the 'isAwaitingUserApproval' property may not exist,
        // so just check uninstalling flag (or consider presence equals installed)
        if !p.isUninstalling {
          return true
        }
      }
    }

    return false
  }

}
