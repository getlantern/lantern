import Foundation

public enum FilePath {
  public static let packageName = {
    Bundle.main.infoDictionary?["BASE_BUNDLE_IDENTIFIER"] as? String ?? "unknown"
  }()

  /// Prepares the file system directories for use
  public static func setupFileSystem() {
    // Setup shared directory
    do {
      try FileManager.default.createDirectory(
        at: FilePath.dataDirectory,
        withIntermediateDirectories: true
      )
      print("data directory created at: \(FilePath.dataDirectory.path)")
    } catch {
      print("Failed to create data directory: \(error.localizedDescription)")
    }

    //Setup log directory
    do {
      try FileManager.default.createDirectory(
        at: FilePath.logsDirectory,
        withIntermediateDirectories: true
      )
      print("logs directory created at: \(FilePath.logsDirectory.path)")
    } catch {
      print("Failed to create logs directory: \(error.localizedDescription)")
    }

    // create support dir
    do {
      let dir = FilePath.appSupportDir()
      if !FileManager.default.fileExists(atPath: dir.path) {
        try? FileManager.default.createDirectory(
          at: dir,
          withIntermediateDirectories: true
        )
      }
    } catch {
      appLogger.error(
        "Failed to create application support directory: \(error.localizedDescription)")
    }

  }

  private static func appSupportDir() -> URL {
    let base = FileManager.default
      .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]

    let bundleId = FilePath.bundleId
    let dir = base.appendingPathComponent(bundleId, isDirectory: true)
    return dir
  }

  public static func isTelemetryEnabled() -> Bool {
    let marker = appSupportDir()
      .appendingPathComponent(".telemetry_enabled")

    return FileManager.default.fileExists(atPath: marker.path)
  }
}

extension FilePath {
  public static let groupName = "group.getlantern.lantern"
    public static  let bundleId = Bundle.main.bundleIdentifier ?? "org.getlantern.lantern"

  private static let containerSharedDirectory: URL! = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: FilePath.groupName)

  public static let sharedDirectory = URL(filePath: "/Users/Shared/Lantern")

  public static var dataDirectory = sharedDirectory

  //Centralize log directory
  public static var logsDirectory =
    sharedDirectory
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
