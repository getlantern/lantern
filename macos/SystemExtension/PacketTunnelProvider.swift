import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {

    static let log = Logger(subsystem: "org.getlantern.lantern", category: "packet-tunnel")
 
    override init() {
        self.log = Self.log
        log.log(level: .debug, "first light")
        super.init()
    }
    
    let log: Logger
    

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the tunnel.
        //let error: Error? = nil // Replace with actual error handling
        //  completionHandler(error)
        // Just log the start of the tunnel for now
        //os_log("Starting tunnel...", log: OSLog.default, type: .info, "PacketTunnelProvider")
         
        let client = "The Mice"
        let answer = 42
        log.log(level: .debug, "run complete, client: \(client), answer: \(answer, privacy: .private)")
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
}
