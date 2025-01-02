//
//  PacketTunnelProvider.swift
//  LanternTunnel
//

import NetworkExtension
import os

// Declare the Go functions
@_silgen_name("StartTunnel")
func StartTunnel() -> Int32

@_silgen_name("StopTunnel")
func StopTunnel()

@_silgen_name("StartTun2Socks")
func StartTun2Socks() -> Int32

class PacketTunnelProvider: NEPacketTunnelProvider {
    let logger = OSLog(subsystem: "org.getlantern.lantern", category: "VPN")
    var connection: NWConnection?
    private var goEngine = GoEngine()

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("Starting tunnel", log: logger, type: .info)

         // Create network settings
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        settings.mtu = NSNumber(value: 1500)

        // Configure IPv4 settings
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])

        // Define the routes that should go through the VPN (Allowed IPs)
        ipv4Settings.includedRoutes = [
            NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "0.0.0.0")
        ]
        // Set DNS settings to prevent leaks
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        settings.dnsSettings = dnsSettings

        ipv4Settings.excludedRoutes = loadExcludedRoutes()
        
        // Assign the IPv4 settings to the network settings
        settings.ipv4Settings = ipv4Settings

        // Apply the network settings
        setTunnelNetworkSettings(settings) { [weak self] error in
            if let error = error {
                completionHandler(error)
                return
            }
            guard let self = self else { 
                completionHandler(nil) 
                return
            }

            os_log("Network settings applied successfully")

            let ret = StartTun2Socks()
            if ret != 0 {
                // handle error
                os_log("Tunnel failed to start")
                let err = NSError(domain: "tun2socksError", code: Int(ret), userInfo: nil)
                completionHandler(err)
                return
            }
            os_log("Tunnel started successfully")
            
            // completionHandler(nil)

            SetSwiftProviderRef(Unmanaged.passUnretained(self).toOpaque())
            completionHandler(nil)

            // Start writing processed packets
            self.readPacketsLoop()
        }
    }

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

    @objc func handleOutboundPacket(_ packetData: NSData) -> Bool {
        // Convert to Swift Data, inject into iOS
        let data = packetData as Data
        return writePacketsToOS([data])
    }
    
    // Called by Go (via bridging) to inject IP packets back to iOS
    func writePacketsToOS(_ packets: [Data]) -> Bool {
        let protoArray = packets.map { _ in NSNumber(value: AF_INET) }
        return packetFlow.writePackets(packets, withProtocols: protoArray)
    }

    private func loadExcludedRoutes() -> [NEIPv4Route] {
        // Loads excluded routes from disk, written by app side
        var routes = [
            NEIPv4Route(destinationAddress: "192.168.0.253", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.8.8", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "8.8.4.4", subnetMask: "255.255.255.255"),
            NEIPv4Route(destinationAddress: "127.0.0.1", subnetMask: "255.255.255.255")
        ]
        return routes
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
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
