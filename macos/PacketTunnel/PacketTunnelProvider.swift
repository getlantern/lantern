//
//  PacketTunnelProvider.swift
//  PacketTunnel
//
//  Created by Adam Fisk on 5/21/25.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    static let logger = Logger(subsystem: "org.getlantern.lantern", category: "PacketTunnelProvider")
    
    let logger: Logger
    
    override init() {
        self.logger = Self.logger
        logger.log(level: .debug, "PacketTunnel first light")
        super.init()
    }

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
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
