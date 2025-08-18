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
    FilePath.dataDirectory = URL(filePath: "/Users/Shared/Lantern")

    appLogger.info("PacketTunnelProvider::Using logs directory \(FilePath.logsDirectory)")
    try await super.startTunnel(options: options)
  }
}
