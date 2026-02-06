//
//  FFIPlatformInterface.swift
//  PacketTunnel
//
//  Implements C callback functions for the Go FFI PlatformInterface.
//  These callbacks are registered with the Go code via registerPlatformCallbacks().
//

import CoreWLAN
import Foundation
import Network
import NetworkExtension
import OSLog

/// Manages the FFI platform interface callbacks for the PacketTunnel extension.
/// This replaces the gomobile UtilsPlatformInterfaceProtocol with C function pointer callbacks.
final class FFIPlatformInterface {
  private weak var tunnel: NEPacketTunnelProvider?
  private var networkSettings: NEPacketTunnelNetworkSettings?
  private var nwMonitor: NWPathMonitor?

  let logger = Logger(subsystem: "org.getlantern.lantern.PacketTunnel", category: "FFI")

  init(_ tunnel: NEPacketTunnelProvider) {
    self.tunnel = tunnel
  }

  /// Registers all platform callbacks with the Go FFI layer.
  func registerCallbacks() {
    // Store self reference for callbacks
    FFIPlatformInterface.sharedInstance = self

    registerPlatformCallbacks(
      openTunCallback,
      clearDNSCacheCallback,
      writeLogCallback,
      restartServiceCallback,
      postServiceCloseCallback,
      usePlatformAutoDetectControlCallback,
      readWIFIStateCallback,
      underNetworkExtensionCallback,
      includeAllNetworksCallback
    )

    logger.info("Platform callbacks registered with Go FFI")
  }

  /// Resets the platform interface state.
  func reset() {
    networkSettings = nil
    nwMonitor?.cancel()
    nwMonitor = nil
  }

  // MARK: - Shared Instance for Callbacks

  // We need a shared instance because C callbacks can't capture Swift context
  static var sharedInstance: FFIPlatformInterface?

  // MARK: - TUN Options Parsing

  struct TunOptionsJSON: Codable {
    let mtu: Int32?
    let autoRoute: Bool?
    let dnsServerAddress: String?
    let inet4Addresses: [String]?
    let inet4Masks: [String]?
    let inet6Addresses: [String]?
    let inet6Prefixes: [Int]?
    let inet4RouteAddresses: [String]?
    let inet4RouteMasks: [String]?
    let inet4RouteExcludeAddresses: [String]?
    let inet4RouteExcludeMasks: [String]?
    let inet6RouteAddresses: [String]?
    let inet6RoutePrefixes: [Int]?
    let inet6RouteExcludeAddresses: [String]?
    let inet6RouteExcludePrefixes: [Int]?
    let httpProxyEnabled: Bool?
    let httpProxyServer: String?
    let httpProxyServerPort: Int32?
    let httpProxyBypassDomains: [String]?
    let httpProxyMatchDomains: [String]?
  }

  // MARK: - OpenTun Implementation

  func openTun(optionsJson: String) -> (Int32, Int32) {
    guard let tunnel = tunnel else {
      logger.error("Tunnel provider not available")
      return (-1, -1)
    }

    guard let jsonData = optionsJson.data(using: .utf8),
      let options = try? JSONDecoder().decode(TunOptionsJSON.self, from: jsonData)
    else {
      logger.error("Failed to parse TUN options JSON")
      return (-1, -1)
    }

    logger.info("Opening TUN with options")

    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

    // Configure MTU
    if let mtu = options.mtu {
      settings.mtu = NSNumber(value: mtu)
    }

    // Configure DNS
    if let dnsServer = options.dnsServerAddress, !dnsServer.isEmpty {
      let dnsSettings = NEDNSSettings(servers: [dnsServer])
      dnsSettings.matchDomains = [""]
      dnsSettings.matchDomainsNoSearch = true
      settings.dnsSettings = dnsSettings
    }

    // Configure IPv4
    if let addresses = options.inet4Addresses,
      let masks = options.inet4Masks,
      !addresses.isEmpty
    {
      let ipv4Settings = NEIPv4Settings(addresses: addresses, subnetMasks: masks)
      var routes: [NEIPv4Route] = []
      var excludeRoutes: [NEIPv4Route] = []

      // Add route addresses
      if let routeAddrs = options.inet4RouteAddresses,
        let routeMasks = options.inet4RouteMasks,
        routeAddrs.count == routeMasks.count
      {
        for i in 0..<routeAddrs.count {
          routes.append(NEIPv4Route(destinationAddress: routeAddrs[i], subnetMask: routeMasks[i]))
        }
      }

      // Use default routes if none specified
      if routes.isEmpty {
        routes = [
          NEIPv4Route(destinationAddress: "1.0.0.0", subnetMask: "255.0.0.0"),
          NEIPv4Route(destinationAddress: "2.0.0.0", subnetMask: "254.0.0.0"),
          NEIPv4Route(destinationAddress: "4.0.0.0", subnetMask: "252.0.0.0"),
          NEIPv4Route(destinationAddress: "8.0.0.0", subnetMask: "248.0.0.0"),
          NEIPv4Route(destinationAddress: "16.0.0.0", subnetMask: "240.0.0.0"),
          NEIPv4Route(destinationAddress: "32.0.0.0", subnetMask: "224.0.0.0"),
          NEIPv4Route(destinationAddress: "64.0.0.0", subnetMask: "192.0.0.0"),
          NEIPv4Route(destinationAddress: "128.0.0.0", subnetMask: "128.0.0.0"),
        ]
      }

      // Add exclude routes
      if let excludeAddrs = options.inet4RouteExcludeAddresses,
        let excludeMasks = options.inet4RouteExcludeMasks,
        excludeAddrs.count == excludeMasks.count
      {
        for i in 0..<excludeAddrs.count {
          excludeRoutes.append(
            NEIPv4Route(destinationAddress: excludeAddrs[i], subnetMask: excludeMasks[i]))
        }
      }

      // Exclude default route
      if !excludeRoutes.contains(where: {
        $0.destinationAddress == "0.0.0.0" && $0.destinationSubnetMask == "255.255.255.254"
      }) {
        excludeRoutes.append(
          NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "255.255.255.254"))
      }

      // Exclude Apple Push Notification service
      if !excludeRoutes.contains(where: {
        $0.destinationAddress == "17.0.0.0" && $0.destinationSubnetMask == "255.0.0.0"
      }) {
        excludeRoutes.append(NEIPv4Route(destinationAddress: "17.0.0.0", subnetMask: "255.0.0.0"))
      }

      ipv4Settings.includedRoutes = routes
      ipv4Settings.excludedRoutes = excludeRoutes
      settings.ipv4Settings = ipv4Settings
    }

    // Configure IPv6
    if let addresses = options.inet6Addresses,
      let prefixes = options.inet6Prefixes,
      !addresses.isEmpty
    {
      let prefixNumbers = prefixes.map { NSNumber(value: $0) }
      let ipv6Settings = NEIPv6Settings(addresses: addresses, networkPrefixLengths: prefixNumbers)
      var routes: [NEIPv6Route] = []
      var excludeRoutes: [NEIPv6Route] = []

      // Add route addresses
      if let routeAddrs = options.inet6RouteAddresses,
        let routePrefixes = options.inet6RoutePrefixes,
        routeAddrs.count == routePrefixes.count
      {
        for i in 0..<routeAddrs.count {
          routes.append(
            NEIPv6Route(
              destinationAddress: routeAddrs[i],
              networkPrefixLength: NSNumber(value: routePrefixes[i])))
        }
      }

      // Use default routes if none specified
      if routes.isEmpty {
        routes = [
          NEIPv6Route(destinationAddress: "100::", networkPrefixLength: 8),
          NEIPv6Route(destinationAddress: "200::", networkPrefixLength: 7),
          NEIPv6Route(destinationAddress: "400::", networkPrefixLength: 6),
          NEIPv6Route(destinationAddress: "800::", networkPrefixLength: 5),
          NEIPv6Route(destinationAddress: "1000::", networkPrefixLength: 4),
          NEIPv6Route(destinationAddress: "2000::", networkPrefixLength: 3),
          NEIPv6Route(destinationAddress: "4000::", networkPrefixLength: 2),
          NEIPv6Route(destinationAddress: "8000::", networkPrefixLength: 1),
        ]
      }

      // Add exclude routes
      if let excludeAddrs = options.inet6RouteExcludeAddresses,
        let excludePrefixes = options.inet6RouteExcludePrefixes,
        excludeAddrs.count == excludePrefixes.count
      {
        for i in 0..<excludeAddrs.count {
          excludeRoutes.append(
            NEIPv6Route(
              destinationAddress: excludeAddrs[i],
              networkPrefixLength: NSNumber(value: excludePrefixes[i])))
        }
      }

      ipv6Settings.includedRoutes = routes
      ipv6Settings.excludedRoutes = excludeRoutes
      settings.ipv6Settings = ipv6Settings
    }

    // Configure HTTP Proxy
    if let proxyEnabled = options.httpProxyEnabled, proxyEnabled,
      let proxyServer = options.httpProxyServer,
      let proxyPort = options.httpProxyServerPort
    {
      let proxySettings = NEProxySettings()
      let server = NEProxyServer(address: proxyServer, port: Int(proxyPort))
      proxySettings.httpServer = server
      proxySettings.httpsServer = server

      var bypassDomains: [String] = options.httpProxyBypassDomains ?? []
      if !bypassDomains.contains("push.apple.com") {
        bypassDomains.append("push.apple.com")
      }
      proxySettings.exceptionList = bypassDomains

      if let matchDomains = options.httpProxyMatchDomains, !matchDomains.isEmpty {
        proxySettings.matchDomains = matchDomains
      }

      settings.proxySettings = proxySettings
    }

    // Apply settings
    networkSettings = settings
    let semaphore = DispatchSemaphore(value: 0)
    var resultError: Error?

    tunnel.setTunnelNetworkSettings(settings) { error in
      resultError = error
      semaphore.signal()
    }

    let waitResult = semaphore.wait(timeout: .now() + 10)
    if waitResult == .timedOut {
      logger.error("setTunnelNetworkSettings timed out")
      return (-1, -1)
    }

    if let error = resultError {
      logger.error("setTunnelNetworkSettings failed: \(error.localizedDescription)")
      return (-1, -1)
    }

    // Get the TUN file descriptor
    if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
      logger.info("Got TUN file descriptor: \(tunFd)")
      return (0, tunFd)
    }

    logger.error("Failed to get TUN file descriptor")
    return (-1, -1)
  }

  // MARK: - DNS Cache

  func clearDNSCache() {
    guard let tunnel = tunnel, let settings = networkSettings else { return }

    tunnel.reasserting = true
    tunnel.setTunnelNetworkSettings(nil) { _ in }
    tunnel.setTunnelNetworkSettings(settings) { _ in }
    tunnel.reasserting = false
  }

  // MARK: - WIFI State

  func readWIFIState() -> String? {
    guard let interface = CWWiFiClient.shared().interface(),
      let ssid = interface.ssid(),
      let bssid = interface.bssid()
    else {
      return nil
    }

    let state = ["ssid": ssid, "bssid": bssid]
    guard let jsonData = try? JSONSerialization.data(withJSONObject: state),
      let jsonString = String(data: jsonData, encoding: .utf8)
    else {
      return nil
    }
    return jsonString
  }
}

// MARK: - C Callback Functions

// These are static C-calling-convention functions that can be passed to Go

private func openTunCallback(optionsJson: UnsafePointer<CChar>?, fd: UnsafeMutablePointer<Int32>?)
  -> Int32
{
  guard let optionsJson = optionsJson, let fd = fd,
    let instance = FFIPlatformInterface.sharedInstance
  else {
    return -1
  }

  let optionsString = String(cString: optionsJson)
  let (result, tunFd) = instance.openTun(optionsJson: optionsString)
  fd.pointee = tunFd
  return result
}

private func clearDNSCacheCallback() {
  FFIPlatformInterface.sharedInstance?.clearDNSCache()
}

private func writeLogCallback(message: UnsafePointer<CChar>?) {
  guard let message = message else { return }
  let messageString = String(cString: message)
  FFIPlatformInterface.sharedInstance?.logger.log("\(messageString)")
}

private func restartServiceCallback() -> Int32 {
  // Restart is handled by the tunnel provider
  return 0
}

private func postServiceCloseCallback() {
  FFIPlatformInterface.sharedInstance?.reset()
}

private func usePlatformAutoDetectControlCallback() -> Int32 {
  return 0
}

private func readWIFIStateCallback() -> UnsafeMutablePointer<CChar>? {
  guard let state = FFIPlatformInterface.sharedInstance?.readWIFIState() else {
    return nil
  }
  return strdup(state)
}

private func underNetworkExtensionCallback() -> Int32 {
  return 1  // Always true in PacketTunnel extension
}

private func includeAllNetworksCallback() -> Int32 {
  return 0
}
