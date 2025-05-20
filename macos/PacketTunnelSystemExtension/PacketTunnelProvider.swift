import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    static let logger = Logger(subsystem: "org.getlantern.lantern", category: "PacketTunnelProvider")
    
    let logger: Logger
    
    override init() {
        self.logger = Self.logger
        logger.log(level: .debug, "first light")
        super.init()
    }

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        self.logger.log(">>>>>>>>PacketTunnelProvider::startTunnel\n\n\n\n")
        // Add code here to start the process of connecting the tunnel.
        print(">>>>>>>>startTunnel")
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        print(">>>>>>>>PacketTunnelProvider::stopTunnel\n\n\n\n")
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        print(">>>>>>>>PacketTunnelProvider::handleAppMessage\n\n\n\n")
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        print(">>>>>>>>PacketTunnelProvider::sleeping...\n\n\n\n")
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
        print(">>>>>>>>PacketTunnelProvider::Waking up...\n\n\n\n")
        self.logger.log(">>>>>>>>Waking up...")
    }
}
