//
//  PacketTunnelProvider.swift
//  LanternTunnel
//

import NetworkExtension
import System
import os

class PacketTunnelProvider: ExtensionProvider {
    let logger = OSLog(subsystem: "org.getlantern.lantern", category: "VPN")

    var connection: NWConnection?

    private var excludedRoutes  = [
            //NEIPv4Route(destinationAddress: "192.168.0.253", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255")
    ]

    override func startTunnel(options: [String: NSObject]?) async throws {
        try await super.startTunnel(options: options)
    }

     // Create network settings
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: 1500)

        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])
        // Define the routes that should go through the VPN (Allowed IPs)
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")
        ]
        ipv4Settings.excludedRoutes = excludedRoutes
        // Assign IPv4 settings to the network settings
        settings.ipv4Settings = ipv4Settings

        // Set DNS settings
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings

        return settings
    }

    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // call radiance stopVPN
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
