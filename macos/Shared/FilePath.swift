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

  public static var dataDirectory = sharedDirectory
  private static var _dataDirectory = sharedDirectory
  private static let dataDirectoryQueue = DispatchQueue(label: "FilePath.dataDirectory.queue")

  public static var dataDirectory: URL {
    get {
      return dataDirectoryQueue.sync { _dataDirectory }
    }
    set {
      dataDirectoryQueue.sync { _dataDirectory = newValue }
    }
  }
  public static var logsDirectory =
    dataDirectory
    .appendingPathComponent("Logs", isDirectory: true)
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
