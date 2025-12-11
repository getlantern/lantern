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
  //    let appLogger = Logger(
  //      subsystem: "org.getlantern.lantern", category: "ExtensionProvider")
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
      guard
        let serverName = options?["netEx.ServerName"] as? String,
        let location = options?["netEx.Location"] as? String
      else {
        writeFatalError("Missing netEx.ServerName or netEx.Location")
        return
      }
      connectToServer(location: location, serverName: serverName)
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

  func startVPN(completion: ((Bool, String?) -> Void)? = nil) {
    appLogger.log("(lantern-tunnel) quick connect")
    var error: NSError?

    MobileStartVPN(platformInterface, opts(), &error)
    if error != nil {
      appLogger.error("error while starting tunnel \(error?.localizedDescription ?? "")")
      // Inform system and close tunnel
      cancelTunnelWithError(error)
      completion?(false, error?.localizedDescription)

      return
    }
    appLogger.log("(lantern-tunnel) tunnel started successfully")
    completion?(true, nil)  // optional call

  }

  func connectToServer(
    location: String, serverName: String, completion: ((Bool, String?) -> Void)? = nil
  ) {
    appLogger.log("(lantern-tunnel) connecting to server")
    var error: NSError?
    MobileConnectToServer(location, serverName, platformInterface, opts(), &error)
    if error != nil {
      appLogger.error("error while connecting to server \(error?.localizedDescription ?? "")")
      cancelTunnelWithError(error)
      completion?(false, error?.localizedDescription)

      return
    }
    appLogger.log("(lantern-tunnel) connected to server successfully")
    completion?(true, nil)  // optional call

  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
    appLogger.log("(lantern-tunnel) stopping, reason:\(String(describing: reason))")
    var error: NSError?
    MobileStopVPN(&error)
    if error != nil {
      appLogger.log("error while stopping tunnel \(error?.localizedDescription ?? "")")
      return
    }
    platformInterface.reset()
  }

  private func stopService() {
    appLogger.info("ExtensionProvider stopService")
    platformInterface.reset()
  }

  func opts() -> UtilsOpts {
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    // opts.deviceid = DeviceIdentifier.getUDID()
    opts.locale = Locale.current.identifier
    opts.logLevel = "trace"
    opts.logDir = FilePath.logsDirectory.relativePath
    appLogger.info("logging to \(opts.logDir)")
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
    platformInterface.reset()
  }

}
