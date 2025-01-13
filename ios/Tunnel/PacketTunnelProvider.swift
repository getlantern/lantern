//
//  PacketTunnelProvider.swift
//  LanternTunnel
//

import NetworkExtension
import os

// Declare Go functions
@_silgen_name("startVPN")
func startVPN() -> Int32

@_silgen_name("stopVPN")
func stopVPN() -> Int32

class PacketTunnelProvider: NEPacketTunnelProvider {
    let logger = OSLog(subsystem: "org.getlantern.lantern", category: "VPN")

    var connection: NWConnection?

    private var goEngine = GoEngine()

    private var excludedRoutes  = [
            NEIPv4Route(destinationAddress: "143.47.98.32", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255")
    ]

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: logger, type: .info)

        // Apply the network settings
        setTunnelNetworkSettings(createTunnelNetworkSettings()) { [weak self] error in
            guard let self = self else {
                completionHandler(nil)
                return
            }

            os_log("Network settings applied successfully")
            SetSwiftProviderRef(Unmanaged.passUnretained(self).toOpaque())

            let ret = startVPN()
            if ret != 0 {
                os_log("Tunnel failed to start")
                let err = NSError(domain: "tun2socksError", code: Int(ret), userInfo: nil)
                completionHandler(err)
                return
            }
            os_log("Tunnel started successfully")

            completionHandler(nil)

            // Start reading packets from the OS
            self.readPacketsLoop()
        }
    }

     // Create network settings
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        settings.mtu = NSNumber(value: 1500)

        let excludedRoutes = 

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


    // Method to handle outbound packets
    @objc func handleOutboundPacket(_ packetData: Data) -> Bool {
        // Convert to Swift Data, inject into iOS
        let data = packetData as Data
        return writePacketsToOS([data])
    }

    func writePacketsToOS(_ packets: [Data]) -> Bool {
        let protoArray = packets.map { _ in NSNumber(value: AF_INET) }
        return packetFlow.writePackets(packets, withProtocols: protoArray)
    }

    // continuously read inbound IP packets from iOS
    func readPacketsLoop() {
        packetFlow.readPackets{ [weak self] packets, protocols in
            guard let self = self else { return }
            for packet in packets {
                self.goEngine.processInboundPacket(packet)
            }
            self.readPacketsLoop()
        }
    }

    private func getTunnelFileDescriptor() -> Int32? {
        var buf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        for fd: Int32 in 0 ... 1024 {
            var len = socklen_t(buf.count)

            if getsockopt(fd, 2 /* IGMP */, 2, &buf, &len) == 0 && String(cString: buf).hasPrefix("utun") {
                return fd
            }
        }
        return packetFlow.value(forKey: "socket.fileDescriptor") as? Int32
    }

   // Method to dynamically exclude a route
   @objc func excludeRoute(_ route: NSString) -> Bool {
       guard let excludedRoute = parseRoute(route as String) else {
            NSLog("Failed to parse route: \(route)")
            return false
        }

        excludedRoutes.append(NEIPv4Route(destinationAddress: route as String, subnetMask: "255.255.255.255"))

        // Apply the updated network settings
        setTunnelNetworkSettings(createTunnelNetworkSettings()) { error in
            if let error = error {
                NSLog("Failed to update tunnel settings: \(error)")
            } else {
                NSLog("Tunnel settings updated successfully with new excluded route: \(route)")
            }
        }
        return true
    }

    private func parseRoute(_ route: String) -> NEIPv4Route? {
        // Split the route into address and subnet mask (e.g., "192.168.1.0/24")
        let components = route.split(separator: "/")
        guard components.count == 2,
              let prefixLength = Int(components[1]),
              prefixLength >= 0, prefixLength <= 32 else {
            return nil
        }

        let address = String(components[0])
        let subnetMask = prefixLengthToSubnetMask(prefixLength)
        return NEIPv4Route(destinationAddress: address, subnetMask: subnetMask)
    }

    private func prefixLengthToSubnetMask(_ prefixLength: Int) -> String {
        var mask = UInt32.max << (32 - prefixLength)
        let bytes = [
            UInt8((mask >> 24) & 0xFF),
            UInt8((mask >> 16) & 0xFF),
            UInt8((mask >> 8) & 0xFF),
            UInt8(mask & 0xFF)
        ]
        return bytes.map { String($0) }.joined(separator: ".")
    }

    private func loadExcludedRoutes() -> [NEIPv4Route] {
        // Loads excluded routes from disk, written by app side
        return [
            NEIPv4Route(destinationAddress: "192.168.0.253", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255")
        ]
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        let ret = stopVPN()
        if ret != 0 {
            os_log("Tunnel failed to stop")
        }
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
