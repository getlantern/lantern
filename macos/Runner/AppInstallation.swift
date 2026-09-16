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
    // A link in Applications is not enough; the app itself must be there.
    let app = bundleURL.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    let applications = applicationsURL.resolvingSymlinksInPath().standardizedFileURL.pathComponents
    return app.count > applications.count && app.starts(with: applications)
  }

  var needsFinder: Bool {
    // Finder handles App Translocation without stripping quarantine attributes.
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
        return InstallationStrings().text("macos_installation_use_finder")
      case .destinationExists:
        return InstallationStrings().text("macos_installation_destination_exists")
      }
    }
  }

  func install(fileManager: FileManager = .default) throws -> URL {
    guard !needsFinder else { throw InstallationError.needsFinder }
    guard !fileManager.fileExists(atPath: destinationURL.path) else {
      throw InstallationError.destinationExists
    }

    // Stage beside the destination so publishing is atomic.
    let stagingURL = applicationsURL.appendingPathComponent(
      ".lantern-install-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(
      at: stagingURL, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
    defer { removeStagingDirectory(stagingURL, fileManager: fileManager) }

    let stagedApp = stagingURL.appendingPathComponent(
      bundleURL.lastPathComponent, isDirectory: true)
    try fileManager.copyItem(at: bundleURL.resolvingSymlinksInPath(), to: stagedApp)
    // RENAME_EXCL also protects against a destination created during the copy.
    let result = stagedApp.withUnsafeFileSystemRepresentation { source in
      destinationURL.withUnsafeFileSystemRepresentation { destination in
        renamex_np(source!, destination!, UInt32(RENAME_EXCL))
      }
    }
    guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    return destinationURL
  }

  func installInBackground(
    fileManager: FileManager = .default, completion: @escaping (Result<URL, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .userInitiated).async {
      let result = Result { try install(fileManager: fileManager) }
      DispatchQueue.main.async { completion(result) }
    }
  }

  private func removeStagingDirectory(_ url: URL, fileManager: FileManager) {
    // A failed copy may leave read-only directories; never chmod through symlinks.
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

struct InstallationStrings {
  var bundle: Bundle = .main

  func text(_ key: String, values: [String: String] = [:]) -> String {
    let localized = bundle.localizedString(forKey: key, value: nil, table: "AppInstallation")
    let result = NSMutableString(string: localized)
    let placeholders = try! NSRegularExpression(pattern: #"\{(\w+)\}"#)
    // Work backwards so replacements don't shift the remaining match ranges.
    for match in placeholders.matches(
      in: localized, range: NSRange(location: 0, length: result.length)
    ).reversed() {
      let name = (localized as NSString).substring(with: match.range(at: 1))
      if let value = values[name] {
        result.replaceCharacters(in: match.range, with: value)
      }
    }
    return result as String
  }
}

enum AppInstallationPreflight {
  static func run(bundle: Bundle = .main) -> Bool {
    run(
      installation: AppInstallation(bundleURL: bundle.bundleURL),
      appName: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Lantern",
      strings: InstallationStrings(bundle: bundle))
  }

  static func run(
    installation: AppInstallation, appName: String,
    strings: InstallationStrings = InstallationStrings()
  ) -> Bool {
    guard !installation.isInstalled else { return true }

    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)

    let values = ["appName": appName]
    let destinationExists = FileManager.default.fileExists(atPath: installation.destinationURL.path)
    let canInstall = !installation.needsFinder && !destinationExists
    let alert = NSAlert()
    alert.alertStyle = .warning
    alert.messageText = strings.text("macos_installation_title", values: values)
    if canInstall {
      alert.informativeText = strings.text("macos_installation_automatic", values: values)
      alert.addButton(withTitle: strings.text("macos_installation_move_relaunch"))
    } else if destinationExists {
      alert.informativeText = strings.text("macos_installation_replace", values: values)
    } else {
      alert.informativeText = strings.text("macos_installation_manual", values: values)
    }
    alert.addButton(withTitle: strings.text("macos_installation_show_applications"))
    alert.addButton(withTitle: strings.text("quit")).keyEquivalent = "\u{1b}"

    let response = alert.runModal()
    if canInstall && response == .alertFirstButtonReturn {
      do {
        let installedURL = try installWithProgress(installation, appName: appName, strings: strings)
        let configuration = NSWorkspace.OpenConfiguration()
        // A normal open can reactivate the process outside Applications.
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: installedURL, configuration: configuration) {
          _, error in
          DispatchQueue.main.async {
            if let error {
              showFailure(
                error, appName: appName, applicationsURL: installation.applicationsURL,
                strings: strings)
            }
            app.terminate(nil)
          }
        }
        app.run()
      } catch {
        showFailure(
          error, appName: appName, applicationsURL: installation.applicationsURL, strings: strings)
      }
    } else if response == (canInstall ? .alertSecondButtonReturn : .alertFirstButtonReturn) {
      NSWorkspace.shared.open(installation.applicationsURL)
    }

    return false
  }

  private static func installWithProgress(
    _ installation: AppInstallation, appName: String, strings: InstallationStrings
  ) throws -> URL {
    let progress = NSAlert()
    progress.messageText = strings.text("macos_installation_progress", values: ["appName": appName])
    progress.informativeText = strings.text("macos_installation_please_wait")
    progress.addButton(withTitle: strings.text("macos_installation_move_relaunch")).isEnabled =
      false
    let indicator = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 300, height: 16))
    indicator.isIndeterminate = true
    indicator.style = .bar
    indicator.setAccessibilityLabel(progress.messageText)
    indicator.startAnimation(nil)
    progress.accessoryView = indicator

    var result: Result<URL, Error>?
    installation.installInBackground { completed in
      result = completed
      NSApplication.shared.stopModal()
    }
    progress.runModal()
    indicator.stopAnimation(nil)
    guard let result else { throw CocoaError(.userCancelled) }
    return try result.get()
  }

  private static func showFailure(
    _ error: Error, appName: String, applicationsURL: URL, strings: InstallationStrings
  ) {
    let failure = NSAlert()
    failure.alertStyle = .warning
    failure.messageText = strings.text("macos_installation_open", values: ["appName": appName])
    failure.informativeText = strings.text(
      "macos_installation_recovery",
      values: ["appName": appName, "error": error.localizedDescription])
    failure.addButton(withTitle: strings.text("macos_installation_show_applications"))
    failure.addButton(withTitle: strings.text("quit")).keyEquivalent = "\u{1b}"
    if failure.runModal() == .alertFirstButtonReturn {
      NSWorkspace.shared.open(applicationsURL)
    }
  }
}
