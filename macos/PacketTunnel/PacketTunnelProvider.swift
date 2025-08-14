import NetworkExtension
import OSLog

public class PacketTunnelProvider: ExtensionProvider {
  static let logger = Logger(subsystem: "org.getlantern.lantern", category: "PacketTunnelProvider")

  let logger: Logger

  override init() {
    self.logger = Self.logger
    logger.log(level: .debug, "PacketTunnel first light")
    super.init()
  }

  public override func startTunnel(options: [String: NSObject]?) async throws {
    logger.log("PacketTunnelProvider starting tunnel")
    // We have to carefully handle the data directory and logs directory here so that the
    // system extension and the main process are looking in the same place. Without this,
    // the system extension will use /var/root because it's running as root, while the
    // main process will use /Users/username.
    guard let usernameObject = options?["username"] else {
      writeFatalError("missing 'username' start option")
      return
    }
    guard let username = usernameObject as? NSString else {
      writeFatalError("username is not an NSString")
      return
    }
    let dataDirString = FilePath.dataDirectory.path
    let newDataDirString = dataDirString.replacingOccurrences(
      of: "/var/root", with: "/Users/\(username)")
    let noPrivateDataDirString = newDataDirString.replacingOccurrences(
        of: "/private", with: "")
    FilePath.dataDirectory = URL(filePath: noPrivateDataDirString)
    FilePath.logsDirectory = FilePath.dataDirectory
      .appendingPathComponent("Logs", isDirectory: true)
    try await super.startTunnel(options: options)
  }
}
