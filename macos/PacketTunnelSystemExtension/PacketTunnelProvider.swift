import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    let logger = Logger(subsystem: "org.getlantern.lantern", category: "PacketTunnelProvider")

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        self.logger.log(">>>>>>>>startTunnel")
        // Add code here to start the process of connecting the tunnel.
        print(">>>>>>>>startTunnel")
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        print(">>>>>>>>stopTunnel")
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        print(">>>>>>>>handleAppMessage")
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        print(">>>>>>>>sleeping...")
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
        print(">>>>>>>>Waking up...")
        self.logger.log(">>>>>>>>Waking up...")
    }
}
