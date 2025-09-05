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

  public static let sharedDirectory = URL(filePath: "/Users/Shared/Lantern")

  public static let libraryDirectory =
    sharedDirectory
    .appendingPathComponent("Library", isDirectory: true)
  
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
