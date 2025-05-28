import NetworkExtension
import OSLog

class PacketTunnelProvider: ExtensionProvider {
    
    static let logger = Logger(subsystem: "org.getlantern.lantern", category: "PacketTunnelProvider")
    
    let logger: Logger
    
    override init() {
      self.logger = Self.logger
      logger.log(level: .debug, "PacketTunnel first light")
      super.init()
    }

    override func startTunnel(options: [String: NSObject]?) async throws {
      logger.log("PacketTunnelProvider starting tunnel")
      try await super.startTunnel(options: options)
    }
}
