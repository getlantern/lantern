import Darwin
import Foundation
import XCTest

@testable import Lantern

final class AppInstallationTests: XCTestCase {
  private var directory: URL!
  private var applications: URL!
  private var source: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    applications = directory.appendingPathComponent("Applications", isDirectory: true)
    source = directory.appendingPathComponent("Downloads/Lantern.app", isDirectory: true)
    try FileManager.default.createDirectory(at: applications, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: source.appendingPathComponent("Contents"), withIntermediateDirectories: true)
    try Data("complete app".utf8).write(to: source.appendingPathComponent("Contents/payload"))
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  private func installation(_ url: URL? = nil) -> AppInstallation {
    AppInstallation(bundleURL: url ?? source, applicationsURL: applications)
  }

  func testOnlyApplicationsDescendantsAreAccepted() {
    for path in ["/Applications/Lantern.app", "/Applications/Utilities/Lantern.app"] {
      XCTAssertTrue(AppInstallation(bundleURL: URL(fileURLWithPath: path)).isInstalled, path)
    }
    for path in [
      "/Users/test/Desktop/Lantern.app", "/Users/test/Downloads/Lantern.app",
      "/Users/test/Applications/Lantern.app", "/Volumes/Lantern/Lantern.app",
      "/private/var/folders/test/AppTranslocation/123/d/Lantern.app",
      "/Applications-old/Lantern.app", "/Applications/../Downloads/Lantern.app", "/Applications",
    ] {
      XCTAssertFalse(AppInstallation(bundleURL: URL(fileURLWithPath: path)).isInstalled, path)
    }
  }

  func testSymlinkInsideApplicationsCannotHideAnOutsideBundle() throws {
    let link = applications.appendingPathComponent("Lantern.app")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
    XCTAssertFalse(installation(link).isInstalled)
  }

  func testSymlinkToInstalledBundleIsAccepted() throws {
    let installed = applications.appendingPathComponent("Lantern.app")
    try FileManager.default.moveItem(at: source, to: installed)
    try FileManager.default.createSymbolicLink(at: source, withDestinationURL: installed)
    XCTAssertTrue(installation().isInstalled)
  }

  func testInstallCopiesCompleteBundleAndPreservesSource() throws {
    let installed = try installation().install()
    XCTAssertTrue(installation(installed).isInstalled)
    XCTAssertEqual(
      try String(contentsOf: installed.appendingPathComponent("Contents/payload")), "complete app")
    XCTAssertEqual(
      try String(contentsOf: source.appendingPathComponent("Contents/payload")), "complete app")
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: applications.path), ["Lantern.app"])
  }

  func testCopyRunsOffMainThreadAndDeliversCompletionOnMainThread() {
    class BlockingCopy: FileManager, @unchecked Sendable {
      let release = DispatchSemaphore(value: 0)
      var started: XCTestExpectation!
      override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        XCTAssertFalse(Thread.isMainThread)
        started.fulfill()
        guard release.wait(timeout: .now() + 5) == .success else {
          throw CocoaError(.userCancelled)
        }
        try super.copyItem(at: srcURL, to: dstURL)
      }
    }
    let fileManager = BlockingCopy()
    fileManager.started = expectation(description: "copy started")
    let completed = expectation(description: "copy completed")
    installation().installInBackground(fileManager: fileManager) { result in
      XCTAssertTrue(Thread.isMainThread)
      if case .failure(let error) = result { XCTFail("Copy failed: \(error)") }
      completed.fulfill()
    }
    wait(for: [fileManager.started], timeout: 5)
    // Main-queue work must run while the copy is waiting.
    DispatchQueue.main.async { fileManager.release.signal() }
    wait(for: [completed], timeout: 5)
  }

  func testBackgroundCopyDeliversFailureOnMainThread() throws {
    try FileManager.default.removeItem(at: source)
    let completed = expectation(description: "copy failed")
    installation().installInBackground { result in
      XCTAssertTrue(Thread.isMainThread)
      if case .success = result { XCTFail("Copy unexpectedly succeeded") }
      completed.fulfill()
    }
    wait(for: [completed], timeout: 5)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: applications.path), [])
  }

  func testLocalizedPlaceholdersPreserveLiteralValues() throws {
    let resourceBundle = directory.appendingPathComponent("Strings.bundle")
    let resources = resourceBundle.appendingPathComponent("Contents/Resources/en.lproj")
    try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
    let info = ["CFBundleIdentifier": UUID().uuidString, "CFBundleDevelopmentRegion": "en"]
    try (info as NSDictionary).write(
      to: resourceBundle.appendingPathComponent("Contents/Info.plist"))
    let table = ["example": "{error}: Open {appName} / {appName}"]
    try (table as NSDictionary).write(
      to: resources.appendingPathComponent("AppInstallation.strings"))
    let bundle = try XCTUnwrap(Bundle(url: resourceBundle))
    XCTAssertEqual(
      InstallationStrings(bundle: bundle).text(
        "example", values: ["error": "100% {appName}", "appName": "Lantern 🌍"]),
      "100% {appName}: Open Lantern 🌍 / Lantern 🌍")
  }

  func testNativeCatalogIsBundledAndUntranslatedPromptsFallBackToEnglish() throws {
    let appBundle = Bundle(for: AppDelegate.self)
    let englishURL = try XCTUnwrap(appBundle.url(forResource: "en", withExtension: "lproj"))
    let english = try XCTUnwrap(Bundle(url: englishURL))
    XCTAssertEqual(
      english.localizedString(forKey: "Move and Relaunch", value: "missing", table: "AppInstallation"),
      "Move and Relaunch")

    let chineseURL = try XCTUnwrap(appBundle.url(forResource: "zh-Hans", withExtension: "lproj"))
    let chinese = InstallationStrings(bundle: try XCTUnwrap(Bundle(url: chineseURL)))
    XCTAssertEqual(chinese.text("Quit"), "退出")
    XCTAssertEqual(
      chinese.text("Move {appName} to Applications to continue", values: ["appName": "Lantern"]),
      "Move Lantern to Applications to continue")
  }

  func testExistingInstallationIsNeverReplaced() throws {
    let installed = try installation().install()
    try Data("existing app".utf8).write(to: installed.appendingPathComponent("Contents/payload"))
    XCTAssertThrowsError(try installation().install())
    XCTAssertEqual(
      try String(contentsOf: installed.appendingPathComponent("Contents/payload")), "existing app")
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testUnwritableSourceParentAndFrameworkSymlinksSurviveInstallation() throws {
    let framework = source.appendingPathComponent("Contents/Frameworks/Test.framework")
    try FileManager.default.createDirectory(
      at: framework.appendingPathComponent("Versions/A"), withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
      atPath: framework.appendingPathComponent("Versions/Current").path,
      withDestinationPath: "A")
    let sourceParent = source.deletingLastPathComponent()
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o555], ofItemAtPath: sourceParent.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: sourceParent.path)
    }

    let installed = try installation().install()
    XCTAssertEqual(
      try FileManager.default.destinationOfSymbolicLink(
        atPath: installed.appendingPathComponent(
          "Contents/Frameworks/Test.framework/Versions/Current"
        ).path),
      "A")
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testUnwritableApplicationsDirectoryLeavesSourceIntact() throws {
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o555], ofItemAtPath: applications.path)
    defer {
      try? FileManager.default.setAttributes(
        [.posixPermissions: 0o755], ofItemAtPath: applications.path)
    }
    XCTAssertThrowsError(try installation().install())
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: applications.path), [])
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testRenamedAppWithSpacesKeepsItsName() throws {
    let renamed = source.deletingLastPathComponent().appendingPathComponent("My Lantern.app")
    try FileManager.default.moveItem(at: source, to: renamed)
    let installed = try installation(renamed).install()
    XCTAssertEqual(installed.lastPathComponent, "My Lantern.app")
    XCTAssertEqual(
      try String(contentsOf: installed.appendingPathComponent("Contents/payload")), "complete app")
  }

  func testPartialCopyFailureLeavesNoInstalledAppOrStagingDirectory() throws {
    class FailingCopy: FileManager, @unchecked Sendable {
      override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try createDirectory(at: dstURL, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: dstURL.appendingPathComponent("partial"))
        try setAttributes([.posixPermissions: 0o555], ofItemAtPath: dstURL.path)
        throw CocoaError(.fileWriteOutOfSpace)
      }
    }
    XCTAssertThrowsError(try installation().install(fileManager: FailingCopy()))
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: applications.path), [])
    XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
  }

  func testConcurrentInstallationIsNotOverwritten() throws {
    class RacingCopy: FileManager, @unchecked Sendable {
      var destination: URL!
      override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try super.copyItem(at: srcURL, to: dstURL)
        try createDirectory(at: destination, withIntermediateDirectories: false)
        try Data("other install".utf8).write(to: destination.appendingPathComponent("marker"))
      }
    }
    let fileManager = RacingCopy()
    fileManager.destination = installation().destinationURL
    XCTAssertThrowsError(try installation().install(fileManager: fileManager))
    XCTAssertEqual(
      try String(contentsOf: fileManager.destination.appendingPathComponent("marker")),
      "other install")
    XCTAssertEqual(
      try FileManager.default.contentsOfDirectory(atPath: applications.path), ["Lantern.app"])
  }

  func testFailedCopyCleanupDoesNotFollowSymlinksIntoSource() throws {
    class FailingSymlinkCopy: FileManager, @unchecked Sendable {
      override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        try createDirectory(at: dstURL, withIntermediateDirectories: true)
        try createSymbolicLink(
          at: dstURL.appendingPathComponent("outside"), withDestinationURL: srcURL)
        throw CocoaError(.fileWriteOutOfSpace)
      }
    }
    try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: source.path)
    defer {
      try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: source.path)
    }
    XCTAssertThrowsError(try installation().install(fileManager: FailingSymlinkCopy()))
    let attributes = try FileManager.default.attributesOfItem(atPath: source.path)
    XCTAssertEqual(attributes[.posixPermissions] as? Int, 0o555)
    XCTAssertEqual(
      try String(contentsOf: source.appendingPathComponent("Contents/payload")), "complete app")
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: applications.path), [])
  }

  func testQuarantinedBundleRequiresFinderAndRetainsQuarantine() throws {
    let value = Array("0083;00000000;Safari;".utf8)
    let result = value.withUnsafeBytes { bytes in
      source.withUnsafeFileSystemRepresentation { path in
        setxattr(path!, "com.apple.quarantine", bytes.baseAddress, bytes.count, 0, 0)
      }
    }
    XCTAssertEqual(result, 0)
    XCTAssertTrue(installation().needsFinder)
    XCTAssertThrowsError(try installation().install())
    XCTAssertTrue(installation().needsFinder)
    XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: applications.path), [])
  }

  func testMissingSourceRequiresManualRecovery() {
    XCTAssertTrue(installation(directory.appendingPathComponent("missing.app")).needsFinder)
  }
}
