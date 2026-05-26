@testable import Lantern
import Foundation
import SystemExtensions
import XCTest

final class RunnerTests: XCTestCase {

  func testHashBundleIsStableForIdenticalContents() throws {
    let firstURL = try createExtensionBundle(
      name: "First.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "first-binary"
    )
    let secondURL = try createExtensionBundle(
      name: "Second.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "first-binary"
    )

    defer {
      try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
      try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
    }

    XCTAssertEqual(
      SystemExtensionBundleHasher.hashBundle(at: firstURL),
      SystemExtensionBundleHasher.hashBundle(at: secondURL)
    )
  }

  func testHashBundleIsStableWhenCodeSignatureChanges() throws {
    let bundleURL = try createExtensionBundle(
      name: "Signed.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "binary-content"
    )

    defer {
      try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
    }

    let hashBefore = SystemExtensionBundleHasher.hashBundle(at: bundleURL)

    // Simulate a re-sign: write new contents into _CodeSignature (as happens each build).
    let codeSignatureDir = bundleURL
      .appendingPathComponent("Contents/_CodeSignature", isDirectory: true)
    try FileManager.default.createDirectory(
      at: codeSignatureDir, withIntermediateDirectories: true)
    try Data("signature-v1".utf8).write(
      to: codeSignatureDir.appendingPathComponent("CodeResources"))

    let hashAfterFirstSign = SystemExtensionBundleHasher.hashBundle(at: bundleURL)
    XCTAssertEqual(hashBefore, hashAfterFirstSign, "_CodeSignature should not affect the hash")

    // Simulate another re-sign with different signature data.
    try Data("signature-v2".utf8).write(
      to: codeSignatureDir.appendingPathComponent("CodeResources"))

    let hashAfterSecondSign = SystemExtensionBundleHasher.hashBundle(at: bundleURL)
    XCTAssertEqual(
      hashAfterFirstSign, hashAfterSecondSign,
      "Changing _CodeSignature contents should not change the hash")
  }

  func testHashBundleChangesWhenBundleContentsChange() throws {
    let firstURL = try createExtensionBundle(
      name: "Original.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "first-binary"
    )
    let secondURL = try createExtensionBundle(
      name: "Changed.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "second-binary"
    )

    defer {
      try? FileManager.default.removeItem(at: firstURL.deletingLastPathComponent())
      try? FileManager.default.removeItem(at: secondURL.deletingLastPathComponent())
    }

    XCTAssertNotEqual(
      SystemExtensionBundleHasher.hashBundle(at: firstURL),
      SystemExtensionBundleHasher.hashBundle(at: secondURL)
    )
  }

  func testReconcileReturnsActivatedWhenEnabledExtensionMatchesBundled() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let enabled = makeDescriptor(build: "220", hash: "hash-a", isEnabled: true)

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabled]
    )

    XCTAssertEqual(reconciliation.status, .activated)
    XCTAssertEqual(reconciliation.action, .none)
    XCTAssertEqual(reconciliation.change, .matched)
  }

  func testReconcileUsesActivationForUpgrade() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let enabled = makeDescriptor(build: "219", hash: "hash-b", isEnabled: true)

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabled]
    )

    XCTAssertEqual(reconciliation.change, .upgrade)
    assertUpdatePending(
      reconciliation.status,
      contains: "bundled system extension is newer"
    )
    assertActivate(
      reconciliation.action,
      contains: "bundled upgrade"
    )
  }

  func testReconcileUsesDeactivateThenActivateForDowngrade() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let enabled = makeDescriptor(build: "221", hash: "hash-b", isEnabled: true)

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabled]
    )

    XCTAssertEqual(reconciliation.change, .downgrade)
    assertUpdatePending(
      reconciliation.status,
      contains: "active system extension is newer"
    )
    assertDeactivateThenActivate(
      reconciliation.action,
      contains: "bundled downgrade"
    )
  }

  func testReconcileUsesDeactivateThenActivateForSameVersionContentChange() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let enabled = makeDescriptor(build: "220", hash: "hash-b", isEnabled: true)

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabled]
    )

    XCTAssertEqual(reconciliation.change, .contentChange)
    assertUpdatePending(
      reconciliation.status,
      contains: "contents differ"
    )
    assertDeactivateThenActivate(
      reconciliation.action,
      contains: "bundled contents"
    )
  }

  func testReconcileRequiresApprovalWhenInstalledExtensionNeedsApproval() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let pendingApproval = makeDescriptor(
      build: "220",
      hash: "hash-a",
      isAwaitingUserApproval: true
    )

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [pendingApproval]
    )

    XCTAssertEqual(reconciliation.status, .requiresApproval)
    XCTAssertEqual(reconciliation.action, .none)
  }

  func testReconcileReplacesEnabledExtensionThatIsUninstallingWhenContentDiffers() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let uninstalling = makeDescriptor(
      build: "220",
      hash: "hash-b",
      isEnabled: true,
      isUninstalling: true
    )

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [uninstalling]
    )

    XCTAssertEqual(reconciliation.change, .contentChange)
    assertUpdatePending(
      reconciliation.status,
      contains: "contents differ"
    )
    assertDeactivateThenActivate(
      reconciliation.action,
      contains: "bundled contents"
    )
  }

  func testReconcileActivatesWhenUninstallingButNoneEnabled() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let uninstalling = makeDescriptor(
      build: "210",
      hash: "hash-b",
      isUninstalling: true
    )

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [uninstalling]
    )

    assertUpdatePending(reconciliation.status, contains: "uninstalling")
    assertActivate(reconciliation.action, contains: "activate")
    XCTAssertEqual(reconciliation.change, .install)
  }

  func testReconcileActivatesBundledExtensionWhenInstalledVersionIsNotEnabled() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")
    let installed = makeDescriptor(build: "220", hash: "hash-a")

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [installed]
    )

    XCTAssertEqual(reconciliation.change, .install)
    assertUpdatePending(
      reconciliation.status,
      contains: "no enabled system extension matches the current app"
    )
    assertActivate(
      reconciliation.action,
      contains: "activate bundled system extension"
    )
  }

  func testReconcileActivatesBundledExtensionWhenNothingIsInstalled() {
    let bundled = makeDescriptor(build: "220", hash: "hash-a")

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: []
    )

    XCTAssertEqual(reconciliation.status, .notInstalled)
    assertActivate(
      reconciliation.action,
      contains: "install bundled system extension"
    )
    XCTAssertEqual(reconciliation.change, .install)
  }

  func testResolveInstalledContentHashCachesByURL() throws {
    SystemExtensionDescriptor._resetInstalledHashCacheForTesting()

    let bundleURL = try createExtensionBundle(
      name: "Cached.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "cache-test-binary"
    )
    defer {
      try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
      SystemExtensionDescriptor._resetInstalledHashCacheForTesting()
    }

    XCTAssertNil(SystemExtensionDescriptor.cachedInstalled(url: bundleURL))

    let firstHash = SystemExtensionDescriptor.resolveInstalledContentHash(
      url: bundleURL,
      isUninstalling: false
    )
    XCTAssertNotNil(firstHash)
    XCTAssertEqual(SystemExtensionDescriptor.cachedInstalled(url: bundleURL), firstHash)

    // Mutate the bundle on disk. If the second call re-hashed, it would
    // produce a different hash; if it served from the cache, it returns the
    // original. The URL-keyed cache is safe in production because installed
    // bundles live at immutable per-UUID paths macOS never overwrites in place.
    let executableURL = bundleURL.appendingPathComponent("Contents/MacOS/PacketTunnel")
    try Data("mutated-binary".utf8).write(to: executableURL)

    let secondHash = SystemExtensionDescriptor.resolveInstalledContentHash(
      url: bundleURL,
      isUninstalling: false
    )
    XCTAssertEqual(
      secondHash, firstHash,
      "Second call should hit the URL cache and return the original hash"
    )

    // Sanity check: hashing the mutated bundle directly produces a different
    // value, proving the cache is what made the second resolve return the old hash.
    let mutatedHash = SystemExtensionBundleHasher.hashBundle(at: bundleURL)
    XCTAssertNotEqual(mutatedHash, firstHash)
  }

  func testResolveInstalledContentHashSkipsHashingForUninstalling() throws {
    SystemExtensionDescriptor._resetInstalledHashCacheForTesting()

    let bundleURL = try createExtensionBundle(
      name: "Uninstalling.systemextension",
      shortVersion: "9.0.18",
      buildVersion: "220",
      executableContents: "uninstalling-binary"
    )
    defer {
      try? FileManager.default.removeItem(at: bundleURL.deletingLastPathComponent())
      SystemExtensionDescriptor._resetInstalledHashCacheForTesting()
    }

    let hash = SystemExtensionDescriptor.resolveInstalledContentHash(
      url: bundleURL,
      isUninstalling: true
    )
    XCTAssertNil(hash, "Uninstalling extensions should not be hashed")
    XCTAssertNil(
      SystemExtensionDescriptor.cachedInstalled(url: bundleURL),
      "Uninstalling extensions should not populate the cache"
    )
  }

  // An uninstalling descriptor with a nil content hash (because we skip hashing
  // for isUninstalling=true) must NOT slip through matches() via the
  // graceful-degradation path in matchesContent. Otherwise an uninstalling
  // extension with stale bytes could mask a legitimate same-version
  // content-change replacement.
  func testMatchesReturnsFalseWhenUninstalling() {
    let bundled = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: "hash-a"
    )
    let uninstalling = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: nil,
      isEnabled: true,
      isUninstalling: true
    )

    XCTAssertFalse(
      uninstalling.matches(bundled),
      "Uninstalling descriptor must not match the bundled extension even when versions agree"
    )
    XCTAssertFalse(
      bundled.matches(uninstalling),
      "matches() should be symmetric — bundled vs uninstalling should also not match"
    )
  }

  // Integration-level: the reconciler given an enabled+uninstalling installed
  // extension (with hash skipped, mimicking what init(properties:) now produces)
  // must NOT return .activated/.none. It should fall through to the
  // isUninstalling handling and produce a replacement.
  func testReconcileReplacesEnabledUninstallingExtensionWithSkippedHash() {
    let bundled = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: "hash-a"
    )
    let enabledUninstalling = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: nil, // skipped because isUninstalling
      isEnabled: true,
      isUninstalling: true
    )

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabledUninstalling]
    )

    XCTAssertEqual(
      reconciliation.change, .contentChange,
      "classifyChange must return .contentChange for an uninstalling same-version copy with a nil contentHash — otherwise the nil-hash fallback would mark it .matched and leave the draining extension in place"
    )
    XCTAssertNotEqual(
      reconciliation.status, .activated,
      "An enabled+uninstalling extension with skipped hash must not be treated as activated"
    )
    XCTAssertNotEqual(
      reconciliation.action, .none,
      "Reconciler must take action rather than leaving a draining extension in place"
    )
  }

  // MARK: - StaleRegistryRecovery

  // Activation failed with extensionNotFound (code 4) and recovery has not
  // been attempted yet — should trigger a deactivate-then-activate recovery.
  func testStaleRegistryRecoveryFiresOnExtensionNotFoundDuringActivation() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertTrue(
      StaleRegistryRecovery.shouldRecover(
        from: error,
        activationFailed: true,
        alreadyAttempted: false
      )
    )
  }

  // Single-shot: once recovery has been attempted in this session, a second
  // extensionNotFound must not trigger another recovery — otherwise we'd
  // loop indefinitely if the deactivation didn't actually clear the state.
  func testStaleRegistryRecoverySkipsSecondAttempt() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertFalse(
      StaleRegistryRecovery.shouldRecover(
        from: error,
        activationFailed: true,
        alreadyAttempted: true
      )
    )
  }

  // Other OSSystemExtensionError codes (missingEntitlement, codeSignatureInvalid,
  // etc.) are real, distinct failures that recovery can't paper over. Only
  // extensionNotFound is the registry-state signal we want to retry through.
  func testStaleRegistryRecoveryIgnoresOtherErrorCodes() {
    let codes: [Int] = [
      OSSystemExtensionError.missingEntitlement.rawValue,
      OSSystemExtensionError.codeSignatureInvalid.rawValue,
      OSSystemExtensionError.validationFailed.rawValue,
      OSSystemExtensionError.unsupportedParentBundleLocation.rawValue,
    ]
    for code in codes {
      let error = NSError(domain: OSSystemExtensionErrorDomain, code: code)
      XCTAssertFalse(
        StaleRegistryRecovery.shouldRecover(
          from: error,
          activationFailed: true,
          alreadyAttempted: false
        ),
        "Should not recover from error code \(code) — that's a distinct failure mode"
      )
    }
  }

  // Activation retry is scoped to activation requests. If a properties-query
  // or deactivation fails with extensionNotFound, shouldRecover must not
  // submit another deactivation request.
  func testStaleRegistryRecoveryDoesNotFireForNonActivationContexts() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertFalse(
      StaleRegistryRecovery.shouldRecover(
        from: error,
        activationFailed: false,
        alreadyAttempted: false
      )
    )
  }

  func testStaleRegistryRecoveryContinuesAfterMissingReplacementDeactivation() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertTrue(
      StaleRegistryRecovery.shouldContinueAfterMissingReplacement(
        from: error,
        replacementDeactivationFailed: true
      )
    )
  }

  func testStaleRegistryRecoveryDoesNotContinueAfterManualDeactivation() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertFalse(
      StaleRegistryRecovery.shouldContinueAfterMissingReplacement(
        from: error,
        replacementDeactivationFailed: false
      )
    )
  }

  func testStaleRegistryRecoveryDoesNotContinueAfterOtherDeactivationErrors() {
    let error = NSError(
      domain: OSSystemExtensionErrorDomain,
      code: OSSystemExtensionError.validationFailed.rawValue
    )
    XCTAssertFalse(
      StaleRegistryRecovery.shouldContinueAfterMissingReplacement(
        from: error,
        replacementDeactivationFailed: true
      )
    )
  }

  // Non-OSSystemExtensionError domain errors (e.g. networking, file IO)
  // bubbling up here would be unexpected, but if they do we should not
  // attempt recovery — the deactivate-then-activate path only makes sense
  // for OS-registry inconsistencies.
  func testStaleRegistryRecoveryRequiresOSSystemExtensionErrorDomain() {
    let error = NSError(
      domain: "SomeOtherDomain",
      code: OSSystemExtensionError.extensionNotFound.rawValue
    )
    XCTAssertFalse(
      StaleRegistryRecovery.shouldRecover(
        from: error,
        activationFailed: true,
        alreadyAttempted: false
      )
    )
  }

  func testClassifyFallsBackToVersionMatchWhenSameVersionHashesAreUnavailable() {
    let bundled = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: nil
    )
    let enabled = SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: "220",
      contentHash: nil,
      isEnabled: true
    )

    let reconciliation = SystemExtensionReconciler.reconcile(
      bundled: bundled,
      installed: [enabled]
    )

    XCTAssertEqual(reconciliation.change, .matched)
    XCTAssertEqual(reconciliation.status, .activated)
    XCTAssertEqual(reconciliation.action, .none)
  }

  private func makeDescriptor(
    build: String,
    hash: String,
    isEnabled: Bool = false,
    isAwaitingUserApproval: Bool = false,
    isUninstalling: Bool = false
  ) -> SystemExtensionDescriptor {
    SystemExtensionDescriptor(
      bundleIdentifier: "org.getlantern.lantern.PacketTunnel",
      bundleShortVersion: "9.0.18",
      bundleVersion: build,
      contentHash: hash,
      isEnabled: isEnabled,
      isAwaitingUserApproval: isAwaitingUserApproval,
      isUninstalling: isUninstalling
    )
  }

  private func assertUpdatePending(_ status: ExtensionStatus, contains snippet: String) {
    guard case .updatePending(let details) = status else {
      XCTFail("Expected updatePending, got \(status)")
      return
    }
    XCTAssertTrue(details.contains(snippet), "Expected '\(details)' to contain '\(snippet)'")
  }

  private func assertRequiresReboot(_ status: ExtensionStatus, contains snippet: String) {
    guard case .requiresReboot(let details) = status else {
      XCTFail("Expected requiresReboot, got \(status)")
      return
    }
    XCTAssertTrue((details ?? "").contains(snippet))
  }

  private func assertActivate(_ action: SystemExtensionInstallAction, contains snippet: String) {
    guard case .activate(let reason) = action else {
      XCTFail("Expected activate action, got \(action)")
      return
    }
    XCTAssertTrue(reason.contains(snippet), "Expected '\(reason)' to contain '\(snippet)'")
  }

  private func assertDeactivateThenActivate(
    _ action: SystemExtensionInstallAction,
    contains snippet: String
  ) {
    guard case .deactivateThenActivate(let reason) = action else {
      XCTFail("Expected deactivateThenActivate action, got \(action)")
      return
    }
    XCTAssertTrue(reason.contains(snippet), "Expected '\(reason)' to contain '\(snippet)'")
  }

  private func createExtensionBundle(
    name: String,
    shortVersion: String,
    buildVersion: String,
    executableContents: String
  ) throws -> URL {
    let rootURL = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let bundleURL = rootURL.appendingPathComponent(name, isDirectory: true)
    let contentsURL = bundleURL.appendingPathComponent("Contents", isDirectory: true)
    let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)

    try FileManager.default.createDirectory(
      at: macOSURL,
      withIntermediateDirectories: true,
      attributes: nil
    )

    let plistURL = contentsURL.appendingPathComponent("Info.plist")
    let executableURL = macOSURL.appendingPathComponent("PacketTunnel")
    let plist: [String: Any] = [
      "CFBundleIdentifier": "org.getlantern.lantern.PacketTunnel",
      "CFBundleShortVersionString": shortVersion,
      "CFBundleVersion": buildVersion,
      "CFBundleExecutable": "PacketTunnel",
    ]
    let plistData = try PropertyListSerialization.data(
      fromPropertyList: plist,
      format: .xml,
      options: 0
    )

    try plistData.write(to: plistURL)
    try Data(executableContents.utf8).write(to: executableURL)

    return bundleURL
  }
}
