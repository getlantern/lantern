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
    try await super.startTunnel(options: options)
  }
    
    public override func stopTunnel(with reason: NEProviderStopReason) async {
        logger.log("PacketTunnelProvider stopping tunnel with reason: \(reason.rawValue)")
        await super.stopTunnel(with: reason)
    }
    
}
