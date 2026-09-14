import AppKit
import Darwin
import Foundation

struct AppInstallation {
  let bundleURL: URL
  var applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)

  var destinationURL: URL {
    applicationsURL.appendingPathComponent(bundleURL.lastPathComponent, isDirectory: true)
  }

  var isInstalled: Bool {
    let app = bundleURL.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    let applications = applicationsURL.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    return app.count > applications.count && app.starts(with: applications)
  }

  var needsFinder: Bool {
    // Copying a quarantined bundle does not reliably clear App Translocation.
    // Let Finder perform that move without changing Gatekeeper's attributes.
    return bundleURL.withUnsafeFileSystemRepresentation { path in
      guard let path else { return true }
      let result = getxattr(path, "com.apple.quarantine", nil, 0, 0, 0)
      return result >= 0 || errno != ENOATTR
    }
  }

  enum InstallationError: LocalizedError {
    case needsFinder
    case destinationExists

    var errorDescription: String? {
      switch self {
      case .needsFinder:
        return NSLocalizedString(
          "Use Finder to move the app into Applications, then open it from there.",
          comment: "Manual app installation instructions")
      case .destinationExists:
        return NSLocalizedString(
          "An app with this name is already in Applications. Use Finder to replace it, then open it from there.",
          comment: "Existing app installation")
      }
    }
  }

  func install(fileManager: FileManager = .default) throws -> URL {
    guard !needsFinder else { throw InstallationError.needsFinder }
    guard !fileManager.fileExists(atPath: destinationURL.path) else {
      throw InstallationError.destinationExists
    }

    // Publish only a complete copy, and never replace an existing installation.
    // Keep the source intact, including when it is on a read-only disk image.
    let stagingURL = applicationsURL.appendingPathComponent(
      ".lantern-install-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
      at: stagingURL, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { removeStagingDirectory(stagingURL, fileManager: fileManager) }

    let stagedApp = stagingURL.appendingPathComponent(
      bundleURL.lastPathComponent, isDirectory: true)
    try fileManager.copyItem(at: bundleURL.resolvingSymlinksInPath(), to: stagedApp)
    // The destination can appear during the copy. Enforce no replacement in the
    // atomic rename itself, rather than relying on the earlier existence check.
    let result = stagedApp.withUnsafeFileSystemRepresentation { source in
      destinationURL.withUnsafeFileSystemRepresentation { destination in
        renamex_np(source!, destination!, UInt32(RENAME_EXCL))
      }
    }
    guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    return destinationURL
  }

  private func removeStagingDirectory(_ url: URL, fileManager: FileManager) {
    // A failed copy can leave read-only directories. Only relax permissions in
    // our private staging directory, without following bundled framework symlinks.
    if let entries = fileManager.enumerator(
      at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
    {
      for case let entry as URL in entries {
        guard
          let values = try? entry.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
          values.isDirectory == true, values.isSymbolicLink != true
        else { continue }
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: entry.path)
      }
    }
    try? fileManager.removeItem(at: url)
  }

}

enum AppInstallationPreflight {
  static func run(bundle: Bundle = .main) -> Bool {
    run(
      installation: AppInstallation(bundleURL: bundle.bundleURL),
      appName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Lantern")
  }

  static func run(installation: AppInstallation, appName: String) -> Bool {
    guard !installation.isInstalled else { return true }

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)

    let destinationExists = FileManager.default.fileExists(atPath: installation.destinationURL.path)
    let canInstall = !installation.needsFinder && !destinationExists
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = String(
      format: NSLocalizedString(
        "Move %@ to Applications to continue",
        comment: "Installation required; placeholder is the app name"), appName)
    if canInstall {
      alert.informativeText =
        String(
          format: NSLocalizedString(
            "%@ needs to run from /Applications to set up its VPN. It will copy itself there and reopen.",
            comment: "Automatic app installation; placeholder is the app name"), appName)
      alert.addButton(
        withTitle: NSLocalizedString("Move and Relaunch", comment: "Installation dialog button"))
    } else if destinationExists {
      alert.informativeText =
        String(
          format: NSLocalizedString(
            "An app with this name is already in /Applications. Quit %@, then use Finder to replace it with the copy you want to use and open it from Applications.",
            comment: "Existing installation; placeholder is the app name"), appName)
    } else {
      alert.informativeText =
        String(
          format: NSLocalizedString(
            "%@ needs to run from /Applications to set up its VPN. Quit the app, then drag it from its download location into Applications in Finder and open it from there.",
            comment: "Manual installation; placeholder is the app name"), appName)
    }
    alert.addButton(
      withTitle: NSLocalizedString("Show Applications", comment: "Installation dialog button"))
    alert.addButton(withTitle: NSLocalizedString("Quit", comment: "Installation dialog button"))
      .keyEquivalent = "\u{1b}"

    let response = alert.runModal()
    if canInstall && response == .alertFirstButtonReturn {
      do {
        let installedURL = try installation.install()
        let configuration = NSWorkspace.OpenConfiguration()
        // A normal open can reactivate the process still running outside Applications.
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: installedURL, configuration: configuration) {
          _, error in
          DispatchQueue.main.async {
            if let error {
              showFailure(error, appName: appName, applicationsURL: installation.applicationsURL)
            }
            app.terminate(nil)
          }
        }
        app.run()
      } catch {
        showFailure(error, appName: appName, applicationsURL: installation.applicationsURL)
      }
    } else if response == (canInstall ? .alertSecondButtonReturn : .alertFirstButtonReturn) {
      NSWorkspace.shared.open(installation.applicationsURL)
    }

    // A relocated app must start in a new process; this process never boots Flutter or Radiance.
    return false
  }

  private static func showFailure(_ error: Error, appName: String, applicationsURL: URL) {
    let failure = NSAlert()
    failure.alertStyle = .warning
    failure.messageText = String(
      format: NSLocalizedString(
        "Open %@ from Applications", comment: "Installation failed; placeholder is the app name"),
      appName)
    failure.informativeText =
      String(
        format: NSLocalizedString(
          "%@\n\nQuit %@, then use Finder to move it to /Applications and open it there. You may need an administrator's permission.",
          comment: "Installation recovery; placeholders are the error and app name"),
        error.localizedDescription, appName)
    failure.addButton(
      withTitle: NSLocalizedString("Show Applications", comment: "Installation dialog button"))
    failure.addButton(withTitle: NSLocalizedString("Quit", comment: "Installation dialog button"))
      .keyEquivalent = "\u{1b}"
    if failure.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(applicationsURL)
    }
  }

}
