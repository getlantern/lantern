//
//  PacketTunnelProvider.swift
//  Tunnel
//
//  Created by jigar fumakiya on 23/05/25.
//

import NetworkExtension

class PacketTunnelProvider: ExtensionProvider {

    override func startTunnel(options : [String : NSObject]?) async throws {
            NSLog("🚀 PacketTunnel: startTunnel called")
        try await super.startTunnel(options: options)
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
