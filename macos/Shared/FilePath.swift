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

  private static let containerSharedDirectory: URL! = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: FilePath.groupName)

  public static let sharedDirectory = containerSharedDirectory!

  public static let libraryDirectory =
    sharedDirectory
    .appendingPathComponent("Library", isDirectory: true)
  public static let cacheDirectory =
    libraryDirectory
    .appendingPathComponent("Caches", isDirectory: true)
    
  public static let logsDirectory =
    FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs", isDirectory: true)
        .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)
    
  public static let dataDirectory =
    FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier!, isDirectory: true)

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
