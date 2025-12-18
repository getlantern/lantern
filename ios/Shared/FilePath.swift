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

  // DO NOT CHANGE THIS
  // This is used to identify the VPN profile created by Lantern in iOS VPN settings
  // if this is changed, existing installations of Lantern will not be able to find profile
  // if needed to change this, a migration path must be implemented
  public static let vpnProfileName = "LanternVPN"

  public static func isTelemetryEnabled() -> Bool {
    let marker =
      sharedDirectory
      .appendingPathComponent(".telemetry_enabled")

    return FileManager.default.fileExists(atPath: marker.path)
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
