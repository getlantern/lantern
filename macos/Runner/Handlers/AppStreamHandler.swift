import AppKit
import CoreServices
import FlutterMacOS
import Foundation
import Liblantern
import UniformTypeIdentifiers

final class AppStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  /// Apps registered with LaunchServices as browsers — dynamic per device
  /// (any installed browser, not a hardcoded list); drives the bypass-list
  /// warning dialog on the Flutter side.
  ///
  /// A browser is an app that handles the http(s) URL scheme AND the HTML
  /// content type. Scheme handling alone over-matches (mail clients, meeting
  /// apps and download managers register for http links too); the HTML check
  /// filters those out. If the HTML query yields nothing we fall back to
  /// scheme-only detection — missing a real browser is worse for users in
  /// censored regions than an extra warning.
  private lazy var browserApps: (bundleIds: Set<String>, paths: Set<String>) = {
    guard let url = URL(string: "https://example.com") else { return ([], []) }
    var appURLs: [URL]
    if #available(macOS 12.0, *) {
      appURLs = NSWorkspace.shared.urlsForApplications(toOpen: url)
      let htmlHandlers = Set(NSWorkspace.shared.urlsForApplications(toOpen: UTType.html))
      if !htmlHandlers.isEmpty {
        appURLs = appURLs.filter { htmlHandlers.contains($0) }
      }
    } else {
      appURLs =
        (LSCopyApplicationURLsForURL(url as CFURL, .viewer)?.takeRetainedValue() as? [URL]) ?? []
      let htmlBundleIds =
        (LSCopyAllRoleHandlersForContentType(kUTTypeHTML, .viewer)?.takeRetainedValue()
          as? [String]).map(Set.init) ?? []
      if !htmlBundleIds.isEmpty {
        appURLs = appURLs.filter { appURL in
          Bundle(url: appURL)?.bundleIdentifier.map { htmlBundleIds.contains($0) } ?? false
        }
      }
    }
    let bundleIds = Set(appURLs.compactMap { Bundle(url: $0)?.bundleIdentifier })
    let paths = Set(appURLs.map { $0.standardizedFileURL.path })
    return (bundleIds, paths)
  }()

  /// Adds "isBrowser" to each app item so Flutter can warn before adding a
  /// browser to the split-tunnel bypass list.
  private func markBrowsers(_ items: [[String: Any]]) -> [[String: Any]] {
    let browsers = browserApps
    return items.map { item in
      var m = item
      let bundleId = (item["bundleId"] as? String) ?? ""
      let appPath = (item["appPath"] as? String) ?? ""
      // browserApps.paths holds standardized paths; standardize the incoming
      // path too so symlinks/relative components don't cause false negatives.
      let standardizedPath = appPath.isEmpty
        ? "" : URL(fileURLWithPath: appPath).standardizedFileURL.path
      m["isBrowser"] =
        (!bundleId.isEmpty && browsers.bundleIds.contains(bundleId))
        || (!standardizedPath.isEmpty && browsers.paths.contains(standardizedPath))
      return m
    }
  }

  private func readCachedApps(dataDir: String) -> [[String: Any]] {
    let cachePath = (dataDir as NSString).appendingPathComponent("apps_cache.json")
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: cachePath)),
      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    else {
      return []
    }
    return arr
  }

  @MainActor
  private func emit(_ payload: [String: Any]) {
    guard let sink = eventSink else { return }
    sink(payload)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events

    Task.detached { [weak self] in
      guard let self else { return }

      let dataDir = FilePath.dataDirectory.path
      let cached = self.markBrowsers(self.readCachedApps(dataDir: dataDir))

      // Send cached snapshot only if stream is still active
      await MainActor.run {
        self.emit([
          "type": "snapshot",
          "items": cached,
          "removed": [],
          "source": "cache",
        ])
      }

      guard self.eventSink != nil else { return }

      var error: NSError?
      let jsonString = MobileLoadInstalledApps(dataDir, &error)

      if let error {
        await MainActor.run {
          self.emit([
            "type": "error",
            "items": [],
            "removed": [],
            "message": error.localizedDescription,
          ])
        }
        return
      }

      if let data = jsonString.data(using: .utf8),
        let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
      {
        let marked = self.markBrowsers(arr)
        await MainActor.run {
          self.emit([
            "type": "snapshot",
            "items": marked,
            "removed": [],
            "source": "scan",
          ])
        }
      }
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
