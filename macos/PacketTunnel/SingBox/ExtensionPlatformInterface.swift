//
//  ExtensionPlatformInterface.swift
//
//  This file is sourced from Sing-Box (https://github.com/SagerNet/sing-box).
//  Original source: sing-box/platform/NetworkUtils.swift
//  Last synced: Commit ae5818ee (March 14, 2025)
//
//  Any modifications should be contributed upstream if possible.
//  Local changes may be overwritten when syncing updates.
//
//  Copyright (c) SagerNet. Licensed under GPLv3.
//

import Foundation
import Liblantern
import NetworkExtension
import OSLog
import UserNotifications

#if os(macOS)
  import CoreWLAN
#endif

public class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol,
  LibboxCommandServerHandlerProtocol
{

  private let tunnel: ExtensionProvider
  private var networkSettings: NEPacketTunnelNetworkSettings?

  init(_ tunnel: ExtensionProvider) {
    self.tunnel = tunnel
  }

  public func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?)
    throws
  {
    appLogger.info("Opening TUN")
    guard let opts = options, let retPtr = ret0_ else {
      throw NSError(domain: "Invalid arguments to openTun", code: 0)
    }
    runBlocking { [self] in
      do {
        try await openTunAsync(opts, retPtr)
      } catch {
        appLogger.error("Error opening TUN: \(error)")
      }
    }
  }

  private func openTunAsync(
    _ options: LibboxTunOptionsProtocol, _ ret0_: UnsafeMutablePointer<Int32>
  ) async throws {
    // Use subranges instead of a single default route
    let autoRouteUseSubRangesByDefault = true
    // Exclude Apple Push Notification Service by default
    let excludeAPNs = true
    //let autoRouteUseSubRangesByDefault = await SharedPreferences.autoRouteUseSubRangesByDefault.get()
    //let excludeAPNs = await SharedPreferences.excludeAPNsRoute.get()
    // Base network settings
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
    appLogger.info("Checking auto route")
    if options.getAutoRoute() {
      settings.mtu = NSNumber(value: options.getMTU())
      let dnsServer = try options.getDNSServerAddress()
      let dnsSettings = NEDNSSettings(servers: [dnsServer.value])
      dnsSettings.matchDomains = [""]
      dnsSettings.matchDomainsNoSearch = true
      settings.dnsSettings = dnsSettings

      var ipv4Address: [String] = []
      var ipv4Mask: [String] = []
      let ipv4AddressIterator = options.getInet4Address()!
      appLogger.info("iterating over ipv4 addresses")
      while ipv4AddressIterator.hasNext() {
        let ipv4Prefix = ipv4AddressIterator.next()!
        ipv4Address.append(ipv4Prefix.address())
        ipv4Mask.append(ipv4Prefix.mask())
      }

      let ipv4Settings = NEIPv4Settings(addresses: ipv4Address, subnetMasks: ipv4Mask)
      var ipv4Routes: [NEIPv4Route] = []
      var ipv4ExcludeRoutes: [NEIPv4Route] = []

      appLogger.info("iterating over ipv4 routes")
      let inet4RouteAddressIterator = options.getInet4RouteAddress()!
      if inet4RouteAddressIterator.hasNext() {
        while inet4RouteAddressIterator.hasNext() {
          let ipv4RoutePrefix = inet4RouteAddressIterator.next()!
          ipv4Routes.append(
            NEIPv4Route(
              destinationAddress: ipv4RoutePrefix.address(), subnetMask: ipv4RoutePrefix.mask()))
        }
      } else if autoRouteUseSubRangesByDefault {
        ipv4Routes.append(NEIPv4Route(destinationAddress: "1.0.0.0", subnetMask: "255.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "2.0.0.0", subnetMask: "254.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "4.0.0.0", subnetMask: "252.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "8.0.0.0", subnetMask: "248.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "16.0.0.0", subnetMask: "240.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "32.0.0.0", subnetMask: "224.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "64.0.0.0", subnetMask: "192.0.0.0"))
        ipv4Routes.append(NEIPv4Route(destinationAddress: "128.0.0.0", subnetMask: "128.0.0.0"))
      } else {
        ipv4Routes.append(NEIPv4Route.default())
      }
      appLogger.info("iterating over ipv4 exclude routes")

      let inet4RouteExcludeAddressIterator = options.getInet4RouteExcludeAddress()!
      while inet4RouteExcludeAddressIterator.hasNext() {
        let ipv4RoutePrefix = inet4RouteExcludeAddressIterator.next()!
        ipv4ExcludeRoutes.append(
          NEIPv4Route(
            destinationAddress: ipv4RoutePrefix.address(), subnetMask: ipv4RoutePrefix.mask()))
      }
      if /*await SharedPreferences.excludeDefaultRoute.get(),*/
      !ipv4Routes.isEmpty {
        if !ipv4ExcludeRoutes.contains(where: { it in
          it.destinationAddress == "0.0.0.0" && it.destinationSubnetMask == "255.255.255.254"
        }) {
          ipv4ExcludeRoutes.append(
            NEIPv4Route(destinationAddress: "0.0.0.0", subnetMask: "255.255.255.254"))
        }
      }
      if excludeAPNs, !ipv4Routes.isEmpty {
        if !ipv4ExcludeRoutes.contains(where: { it in
          it.destinationAddress == "17.0.0.0" && it.destinationSubnetMask == "255.0.0.0"
        }) {
          ipv4ExcludeRoutes.append(
            NEIPv4Route(destinationAddress: "17.0.0.0", subnetMask: "255.0.0.0"))
        }
      }

      ipv4Settings.includedRoutes = ipv4Routes
      ipv4Settings.excludedRoutes = ipv4ExcludeRoutes
      settings.ipv4Settings = ipv4Settings

      var ipv6Address: [String] = []
      var ipv6Prefixes: [NSNumber] = []
      let ipv6AddressIterator = options.getInet6Address()!
      while ipv6AddressIterator.hasNext() {
        let ipv6Prefix = ipv6AddressIterator.next()!
        ipv6Address.append(ipv6Prefix.address())
        ipv6Prefixes.append(NSNumber(value: ipv6Prefix.prefix()))
      }
      let ipv6Settings = NEIPv6Settings(addresses: ipv6Address, networkPrefixLengths: ipv6Prefixes)
      var ipv6Routes: [NEIPv6Route] = []
      var ipv6ExcludeRoutes: [NEIPv6Route] = []

      let inet6RouteAddressIterator = options.getInet6RouteAddress()!
      if inet6RouteAddressIterator.hasNext() {
        while inet6RouteAddressIterator.hasNext() {
          let ipv6RoutePrefix = inet6RouteAddressIterator.next()!
          ipv6Routes.append(
            NEIPv6Route(
              destinationAddress: ipv6RoutePrefix.address(),
              networkPrefixLength: NSNumber(value: ipv6RoutePrefix.prefix())))
        }
      } else if autoRouteUseSubRangesByDefault {
        ipv6Routes.append(NEIPv6Route(destinationAddress: "100::", networkPrefixLength: 8))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "200::", networkPrefixLength: 7))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "400::", networkPrefixLength: 6))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "800::", networkPrefixLength: 5))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "1000::", networkPrefixLength: 4))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "2000::", networkPrefixLength: 3))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "4000::", networkPrefixLength: 2))
        ipv6Routes.append(NEIPv6Route(destinationAddress: "8000::", networkPrefixLength: 1))
      } else {
        ipv6Routes.append(NEIPv6Route.default())
      }

      let inet6RouteExcludeAddressIterator = options.getInet6RouteExcludeAddress()!
      while inet6RouteExcludeAddressIterator.hasNext() {
        let ipv6RoutePrefix = inet6RouteExcludeAddressIterator.next()!
        ipv6ExcludeRoutes.append(
          NEIPv6Route(
            destinationAddress: ipv6RoutePrefix.address(),
            networkPrefixLength: NSNumber(value: ipv6RoutePrefix.prefix())))
      }

      ipv6Settings.includedRoutes = ipv6Routes
      ipv6Settings.excludedRoutes = ipv6ExcludeRoutes
      settings.ipv6Settings = ipv6Settings
    }
    appLogger.info("Checking if HTTP proxy is enabled...")

    if options.isHTTPProxyEnabled() {
      let proxySettings = NEProxySettings()
      let proxyServer = NEProxyServer(
        address: options.getHTTPProxyServer(), port: Int(options.getHTTPProxyServerPort()))
      proxySettings.httpServer = proxyServer
      proxySettings.httpsServer = proxyServer
      // if await SharedPreferences.systemProxyEnabled.get() {
      //     proxySettings.httpEnabled = true
      //     proxySettings.httpsEnabled = true
      // }
      var bypassDomains: [String] = []
      let bypassDomainIterator = options.getHTTPProxyBypassDomain()!
      while bypassDomainIterator.hasNext() {
        bypassDomains.append(bypassDomainIterator.next())
      }
      if excludeAPNs {
        if !bypassDomains.contains(where: { it in
          it == "push.apple.com"
        }) {
          bypassDomains.append("push.apple.com")
        }
      }
      if !bypassDomains.isEmpty {
        proxySettings.exceptionList = bypassDomains
      }
      var matchDomains: [String] = []
      let matchDomainIterator = options.getHTTPProxyMatchDomain()!
      while matchDomainIterator.hasNext() {
        matchDomains.append(matchDomainIterator.next())
      }
      if !matchDomains.isEmpty {
        proxySettings.matchDomains = matchDomains
      }
      settings.proxySettings = proxySettings
    }

    appLogger.info("Setting network settings...")

    networkSettings = settings
    appLogger.info("Setting tunnel network settings to \(settings)...")
    try await tunnel.setTunnelNetworkSettings(settings)

    appLogger.info("Accessing the socket file descriptor...")
    if let tunFd = tunnel.packetFlow.value(forKeyPath: "socket.fileDescriptor") as? Int32 {
      ret0_.pointee = tunFd
      appLogger.info("Returning tunnel file descriptor \(tunFd)")
      return
    }

    appLogger.info("Accessing tunnel file descriptor from C loop...")
    let tunFdFromLoop = LibboxGetTunnelFileDescriptor()
    guard tunFdFromLoop != -1 else {
      throw NSError(domain: "Missing TUN FD", code: 0)
    }
    ret0_.pointee = tunFdFromLoop
  }

  public func usePlatformAutoDetectControl() -> Bool {
    appLogger.info("ExtensionPlatformInterface::usePlatformAutoDetectControl")
    return false
  }

  public func autoDetectControl(_: Int32) throws {}

  public func findConnectionOwner(
    _: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?,
    destinationPort _: Int32, ret0_ _: UnsafeMutablePointer<Int32>?
  ) throws {
    throw NSError(domain: "not implemented", code: 0)
  }

  public func packageName(byUid _: Int32, error _: NSErrorPointer) -> String {
    return ""
  }

  public func uid(byPackageName _: String?, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
    throw NSError(domain: "not implemented", code: 0)
  }

  public func useProcFS() -> Bool {
    return false
  }

  public func writeLog(_ message: String?) {
    guard let message else {
      return
    }
    appLogger.log("\(String(describing: message))")
  }

  private var nwMonitor: NWPathMonitor? = nil

  public func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?)
    throws
  {
    appLogger.info("startDefaultInterfaceMonitor")
    guard let listener else {
      appLogger.error("startDefaultInterfaceMonitor: listener is nil")
      return
    }
    appLogger.info("startDefaultInterfaceMonitor: monitoring default interface")
    let monitor = NWPathMonitor()
    nwMonitor = monitor
    let semaphore = DispatchSemaphore(value: 0)
    monitor.pathUpdateHandler = { path in
      self.onUpdateDefaultInterface(listener, path)
      semaphore.signal()
      monitor.pathUpdateHandler = { path in
        self.onUpdateDefaultInterface(listener, path)
      }
    }
    monitor.start(queue: DispatchQueue.global())
    semaphore.wait()
  }

  private func onUpdateDefaultInterface(
    _ listener: LibboxInterfaceUpdateListenerProtocol, _ path: Network.NWPath
  ) {
    if path.status == .unsatisfied {
      listener.updateDefaultInterface(
        "", interfaceIndex: -1, isExpensive: false, isConstrained: false)
    } else {
      let defaultInterface = path.availableInterfaces.first!
      listener.updateDefaultInterface(
        defaultInterface.name, interfaceIndex: Int32(defaultInterface.index),
        isExpensive: path.isExpensive, isConstrained: path.isConstrained)
    }
  }

  public func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
    appLogger.info("Close default interface monitor")
    nwMonitor?.cancel()
    nwMonitor = nil
  }

  public func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
    guard let nwMonitor else {
      throw NSError(domain: "NWMonitor not started", code: 0)
    }
    let path = nwMonitor.currentPath
    if path.status == .unsatisfied {
      return networkInterfaceArray([])
    }
    var interfaces: [LibboxNetworkInterface] = []
    for it in path.availableInterfaces {
      let interface = LibboxNetworkInterface()
      interface.name = it.name
      interface.index = Int32(it.index)
      switch it.type {
      case .wifi:
        interface.type = LibboxInterfaceTypeWIFI
      case .cellular:
        interface.type = LibboxInterfaceTypeCellular
      case .wiredEthernet:
        interface.type = LibboxInterfaceTypeEthernet
      default:
        interface.type = LibboxInterfaceTypeOther
      }
      interfaces.append(interface)
    }
    return networkInterfaceArray(interfaces)
  }

  class networkInterfaceArray: NSObject, LibboxNetworkInterfaceIteratorProtocol {
    private var iterator: IndexingIterator<[LibboxNetworkInterface]>
    init(_ array: [LibboxNetworkInterface]) {
      iterator = array.makeIterator()
    }

    private var nextValue: LibboxNetworkInterface? = nil

    func hasNext() -> Bool {
      nextValue = iterator.next()
      return nextValue != nil
    }

    func next() -> LibboxNetworkInterface? {
      nextValue
    }
  }

  public func underNetworkExtension() -> Bool {
    true
  }

  public func includeAllNetworks() -> Bool {
    return false
  }

  public func clearDNSCache() {
    guard let networkSettings else {
      return
    }
    tunnel.reasserting = true
    tunnel.setTunnelNetworkSettings(nil) { _ in
    }
    tunnel.setTunnelNetworkSettings(networkSettings) { _ in
    }
    tunnel.reasserting = false
  }

  public func readWIFIState() -> LibboxWIFIState? {
    #if os(iOS)
      let network = runBlocking {
        await NEHotspotNetwork.fetchCurrent()
      }
      guard let network else {
        return nil
      }
      return LibboxWIFIState(network.ssid, wifiBSSID: network.bssid)!
    #elseif os(macOS)
      guard let interface = CWWiFiClient.shared().interface() else {
        return nil
      }
      guard let ssid = interface.ssid() else {
        return nil
      }
      guard let bssid = interface.bssid() else {
        return nil
      }
      return LibboxWIFIState(ssid, wifiBSSID: bssid)!
    #else
      return nil
    #endif
  }

  public func getSystemProxyStatus() -> LibboxSystemProxyStatus? {
    let status = LibboxSystemProxyStatus()
    guard let networkSettings else {
      return status
    }
    guard let proxySettings = networkSettings.proxySettings else {
      return status
    }
    if proxySettings.httpServer == nil {
      return status
    }
    status.available = true
    status.enabled = proxySettings.httpEnabled
    return status
  }

  public func setSystemProxyEnabled(_ isEnabled: Bool) throws {
    guard let networkSettings else {
      return
    }
    guard let proxySettings = networkSettings.proxySettings else {
      return
    }
    if proxySettings.httpServer == nil {
      return
    }
    if proxySettings.httpEnabled == isEnabled {
      return
    }
    proxySettings.httpEnabled = isEnabled
    proxySettings.httpsEnabled = isEnabled
    networkSettings.proxySettings = proxySettings
    try runBlocking {
      try await self.tunnel.setTunnelNetworkSettings(networkSettings)
    }
  }

  func reset() {
    networkSettings = nil
  }

  public func serviceReload() throws {
    runBlocking { [self] in
      tunnel.reloadService()
    }
  }

  public func postServiceClose() {
    reset()
    tunnel.postServiceClose()
  }

  public func send(_ notification: LibboxNotification?) throws {
    #if !os(tvOS)
      guard let notification else {
        return
      }
      let center = UNUserNotificationCenter.current()
      let content = UNMutableNotificationContent()

      content.title = notification.title
      content.subtitle = notification.subtitle
      content.body = notification.body
      if !notification.openURL.isEmpty {
        content.userInfo["OPEN_URL"] = notification.openURL
        content.categoryIdentifier = "OPEN_URL"
      }
      content.interruptionLevel = .active
      let request = UNNotificationRequest(
        identifier: notification.identifier, content: content, trigger: nil)
      try runBlocking {
        try await center.requestAuthorization(options: [.alert])
        try await center.add(request)
      }
    #endif
  }

  public func localDNSTransport() -> (any LibboxLocalDNSTransportProtocol)? {
    nil
  }

  public func systemCertificates() -> (any LibboxStringIteratorProtocol)? {
    nil
  }
}
