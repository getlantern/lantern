//
//  FilePath.swift
//  Shared
//
//  Created by GFWFighter on 7/25/1402 AP.
//

import Foundation

public enum FilePath {
  public static let packageName = {
    Bundle.main.infoDictionary?["BASE_BUNDLE_IDENTIFIER"] as? String ?? "unknown"
  }()
}

extension FilePath {
  public static let groupName = "group.getlantern.lantern"

  private static let defaultSharedDirectory: URL! = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: FilePath.groupName)

  public static let sharedDirectory = defaultSharedDirectory!

  public static let logsDirectory =
    sharedDirectory
    .appendingPathComponent("Logs", isDirectory: true)

  // Subdirectory for all Go backend data files.
  // Using a subdirectory (not the App Group root) prevents the file watcher
  // from trying to lstat system-managed files like
  // .com.apple.mobile_container_manager.metadata.plist, which the Network
  // Extension sandbox cannot access.
  public static let dataDirectory =
    sharedDirectory
    .appendingPathComponent("data", isDirectory: true)

  // DO NOT CHANGE THIS
  // This is used to identify the VPN profile created by Lantern in iOS VPN settings
  // if this is changed, existing installations of Lantern will not be able to find profile
  // if needed to change this, a migration path must be implemented
  public static let vpnProfileName = "LanternVPN"

  private static func appSupportDir() -> URL {
    let base = FileManager.default
      .urls(for: .documentDirectory, in: .userDomainMask)[0]
    let dir = base.appendingPathComponent(".lantern", isDirectory: true)

    return dir
  }

  public static func isTelemetryEnabled() -> Bool {
    let marker =
      appSupportDir()
      .appendingPathComponent(".telemetry_enabled")

    return FileManager.default.fileExists(atPath: marker.path)
  }

  public static func isRadianceEnv() -> String {
    let marker = appSupportDir()
      .appendingPathComponent(".radiance_env")

    if FileManager.default.fileExists(atPath: marker.path) {
      return "stage"
    }
    return "prod"
  }

}

extension URL {
  public var fileName: String {
    var path = relativePath
    if let index = path.lastIndex(of: "/") {
      path = String(path[path.index(index, offsetBy: 1)...])
    }
    return path
  }
}
