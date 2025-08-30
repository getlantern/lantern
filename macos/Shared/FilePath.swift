import Foundation

public enum FilePath {
  public static let packageName = "org.getlantern.lantern"
  public static let systemExtensionName = "org.getlantern.lantern.PacketTunnel"
}

extension FilePath {
  public static let groupName = "group.getlantern.lantern"

  private static let containerSharedDirectory: URL! = FileManager.default.containerURL(
    forSecurityApplicationGroupIdentifier: FilePath.groupName)

  public static let sharedDirectory = containerSharedDirectory!

  public static let libraryDirectory =
    sharedDirectory
    .appendingPathComponent("Library", isDirectory: true)

    public static var dataDirectory = URL(filePath: "/Users/Shared/Lantern")
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
