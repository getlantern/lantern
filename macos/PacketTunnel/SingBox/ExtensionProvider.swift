//
//  ExtensionProvider.swift
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

#if os(iOS)
  import WidgetKit
#endif
#if os(macOS)
  import CoreLocation
#endif

public class ExtensionProvider: NEPacketTunnelProvider {
  private var platformInterface: ExtensionPlatformInterface!

  override open func startTunnel(options: [String: NSObject]?) async throws {
    if platformInterface == nil {
      platformInterface = ExtensionPlatformInterface(self)
    }
    let tunnelType = options?["netEx.Type"] as? String
    switch tunnelType {
    case "Lantern":
      appLogger.info("(lantern-tunnel) user initiated connection")
      startVPN()
    case "PrivateServer":
      let serverName = options?["netEx.ServerName"] as? String
      let location = options?["netEx.Location"] as? String
      connectToServer(location: location!, serverName: serverName!)
    default:
      // Fallback or unknown type
      appLogger.info("(lantern-tunnel) unknown tunnel type \(String(describing: tunnelType))")
      startVPN()
    }
  }

  public func writeFatalError(_ message: String) {
    appLogger.error("\(String(describing: message))")
    var error: NSError?
    LibboxWriteServiceError(message, &error)
    cancelTunnelWithError(nil)
  }

  func startVPN() {
    appLogger.log("(lantern-tunnel) quick connect")
      appLogger.log("Data directory: \(FilePath.dataDirectory.relativePath)")
      
    var error: NSError?

    MobileStartVPN(platformInterface, opts(), &error)
    if error != nil {
      appLogger.error("error while starting tunnel \(error?.localizedDescription ?? "")")
      // Inform system and close tunnel
      cancelTunnelWithError(error)
      return
    }
    appLogger.log("(lantern-tunnel) tunnel started successfully")
  }

  func connectToServer(location: String, serverName: String) {
    appLogger.log("(lantern-tunnel) connecting to server")
    var error: NSError?
    MobileConnectToServer(location, serverName, platformInterface, opts(), &error)
    if error != nil {
      appLogger.error("error while connecting to server \(error?.localizedDescription ?? "")")
      cancelTunnelWithError(error)
      return
    }
    appLogger.log("(lantern-tunnel) connected to server successfully")
  }

  private func stopService() {
    appLogger.info("ExtensionProvider stopService")
    platformInterface.reset()
  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
    appLogger.log("(lantern-tunnel) stopping, reason:\(String(describing: reason))")
    stopService()
  }

  func opts() -> UtilsOpts {
    appLogger.log("Generating opts for lantern tunnel")
    appLogger.log("Data directory: \(FilePath.dataDirectory.relativePath)")
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    opts.logDir = FilePath.logsDirectory.relativePath
    opts.locale = Locale.current.identifier
    opts.deviceid = ""
    opts.logLevel = "debug"
      appLogger.info("Opts dataDir: \(opts.dataDir), logDir: \(opts.logDir), locale: \(opts.locale), deviceid: \(opts.deviceid), logLevel: \(opts.logLevel)")
    return opts
  }

  override open func sleep() async {
    // if let boxService {
    //     boxService.pause()
    // }
  }

  override open func wake() {
    // if let boxService {
    //     boxService.wake()
    // }
  }

  func reloadService() {
    appLogger.log("(lantern-tunnel) reloading service")
    reasserting = true
    defer {
      reasserting = false
    }
    stopService()
    startVPN()
  }

  func postServiceClose() {
    //    radiance = nil
    platformInterface.reset()
  }

}
