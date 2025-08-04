//
//  FilePath.swift
//  Shared
//
//  Created by GFWFighter on 7/25/1402 AP.
//

import Foundation

public enum FilePath {
  public static let packageName = "org.getlantern.lantern"
  public static let systemExtensionName = "org.getlantern.lantern.packet"
}

extension FilePath {
  public static let groupName = "group.getlantern.lantern"

  private static let defaultSharedDirectory: URL! = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: FilePath.groupName)

  public static let sharedDirectory = defaultSharedDirectory!

  public static let libraryDirectory =
    sharedDirectory
    .appendingPathComponent("Library", isDirectory: true)
  public static let cacheDirectory =
    libraryDirectory
    .appendingPathComponent("Caches", isDirectory: true)
  public static let logsDirectory =
    libraryDirectory
    .appendingPathComponent("Logs", isDirectory: true)

  public static let workingDirectory = cacheDirectory.appendingPathComponent(
    "Working", isDirectory: true)
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
