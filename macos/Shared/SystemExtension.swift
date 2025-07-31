import Foundation
import SystemExtensions

public class SystemExtension: NSObject, OSSystemExtensionRequestDelegate {
  private let forceUpdate: Bool
  private let inBackground: Bool
  private let semaphore = DispatchSemaphore(value: 0)
  private var result: OSSystemExtensionRequest.Result?
  private var properties: [OSSystemExtensionProperties]?
  private var error: Error?

  private init(_ forceUpdate: Bool = false, _ inBackground: Bool = false) {
    self.forceUpdate = forceUpdate
    self.inBackground = inBackground
  }

  public func request(
    _: OSSystemExtensionRequest, actionForReplacingExtension existing: OSSystemExtensionProperties,
    withExtension ext: OSSystemExtensionProperties
  ) -> OSSystemExtensionRequest.ReplacementAction {
    if forceUpdate {
      return .replace
    }
    if existing.isAwaitingUserApproval, !inBackground {
      return .replace
    }
    if existing.bundleIdentifier == ext.bundleIdentifier,
      existing.bundleVersion == ext.bundleVersion,
      existing.bundleShortVersion == ext.bundleShortVersion
    {
      NSLog("Skip update system extension")
      return .cancel
    } else {
      NSLog("Update system extension")
      return .replace
    }
  }

  public func requestNeedsUserApproval(_: OSSystemExtensionRequest) {
    semaphore.signal()
  }

  public func request(
    _: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result
  ) {
    self.result = result
    semaphore.signal()
  }

  public func request(_: OSSystemExtensionRequest, didFailWithError error: Error) {
    self.error = error
    semaphore.signal()
  }

  public func request(
    _: OSSystemExtensionRequest, foundProperties properties: [OSSystemExtensionProperties]
  ) {
    self.properties = properties
    semaphore.signal()
  }

  public func activation() throws -> OSSystemExtensionRequest.Result? {
    let request = OSSystemExtensionRequest.activationRequest(
      forExtensionWithIdentifier: FilePath.systemExtensionName, queue: .main)
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
    semaphore.wait()
    if let error {
      throw error
    }
    return result
  }

  public func deactivation() throws -> OSSystemExtensionRequest.Result? {
    let request = OSSystemExtensionRequest.deactivationRequest(
      forExtensionWithIdentifier: FilePath.systemExtensionName , queue: .main)
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
    semaphore.wait()
    if let error {
      throw error
    }
    return result
  }

  public func getProperties() throws -> [OSSystemExtensionProperties] {
    let request = OSSystemExtensionRequest.propertiesRequest(
      forExtensionWithIdentifier: FilePath.packageName + ".system", queue: .main)
    request.delegate = self
    OSSystemExtensionManager.shared.submitRequest(request)
    semaphore.wait()
    if let error {
      throw error
    }
    return properties!
  }

  public static func isInstalled() async -> Bool {
    await
      (try? Task {
        try await isInstalledBackground()
      }.result.get()) == true
  }

  public nonisolated static func isInstalledBackground() async throws -> Bool {
    for _ in 0..<3 {
      do {
        let propList = try SystemExtension().getProperties()
        if propList.isEmpty {
          return false
        }
        for extensionProp in propList {
          if !extensionProp.isAwaitingUserApproval, !extensionProp.isUninstalling {
            return true
          }
        }
      } catch {
        try await Task.sleep(nanoseconds: NSEC_PER_SEC)
      }
    }
    return false
  }

  public nonisolated static func install(forceUpdate: Bool = false, inBackground: Bool = false)
    async throws -> OSSystemExtensionRequest.Result?
  {
    try await Task.detached {
      try SystemExtension(forceUpdate, inBackground).activation()
    }.result.get()
  }

  public nonisolated static func uninstall() async throws -> OSSystemExtensionRequest.Result? {
    try await Task.detached {
      try SystemExtension().deactivation()
    }.result.get()
  }
}
