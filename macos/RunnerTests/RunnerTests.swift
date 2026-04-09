@testable import Lantern
import Foundation
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

  func testReconcileRequiresRebootWhenEnabledExtensionIsUninstalling() {
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

    assertRequiresReboot(
      reconciliation.status,
      contains: "waiting on a reboot"
    )
    XCTAssertEqual(reconciliation.action, .none)
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
