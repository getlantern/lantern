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

#if os(iOS)
  import WidgetKit
#endif
#if os(macOS)
  import CoreLocation
#endif

class ExtensionProvider: NEPacketTunnelProvider {
  private var platformInterface: ExtensionPlatformInterface!

  override open func startTunnel(options: [String: NSObject]?) async throws {
    if platformInterface == nil {
      platformInterface = ExtensionPlatformInterface(self)
    }

    // Start the IPC server before any VPN operations
    var ipcError: NSError?
    MobileStartIPCServer(platformInterface, opts(), &ipcError)
    if let ipcError {
      appLogger.error("error starting IPC server: \(ipcError.localizedDescription)")
      throw ipcError
    }

    let tunnelType = options?["netEx.Type"] as? String
    switch tunnelType {
    case "Lantern":
      startVPN()
    case "PrivateServer":
      let serverName = options?["netEx.ServerName"] as? String
      connectToServer(serverName: serverName!)
    default:
      // Fallback or unknown type
      startVPN()
    }
  }

  public func writeFatalError(_ message: String) {
    appLogger.error(message)
    var error: NSError?
    LibboxWriteServiceError(message, &error)
    cancelTunnelWithError(nil)
  }

  func startVPN(completion: ((Bool, String?) -> Void)? = nil) {
    appLogger.log("(lantern-tunnel) quick connect")
    var error: NSError?

    MobileStartVPN(&error)
    if error != nil {
      appLogger.log("error while starting tunnel \(error?.localizedDescription ?? "")")
      // Inform system and close tunnel
      completion?(false, error?.localizedDescription)
      cancelTunnelWithError(error)

      return
    }
    completion?(true, nil)
    appLogger.log("(lantern-tunnel) tunnel started successfully")
  }

  func connectToServer(
    serverName: String, completion: ((Bool, String?) -> Void)? = nil
  ) {
    appLogger.log("(lantern-tunnel) connecting to server")
    var error: NSError?
    MobileConnectToServer(serverName, &error)
    if error != nil {
      appLogger.log("error while connecting to server \(error?.localizedDescription ?? "")")
      completion?(false, error?.localizedDescription)
      cancelTunnelWithError(error)

      return
    }
    completion?(true, nil)
    appLogger.log("(lantern-tunnel) connected to server successfully")
  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
    let startTime = Date()
    appLogger.log("(lantern-tunnel) stopping, reason: \(reason)")
    stopService()
    var error: NSError?
    MobileCloseIPCServer(&error)
    if error != nil {
      appLogger.log("error closing IPC server \(error?.localizedDescription ?? "")")
    }
    let elapsed = Date().timeIntervalSince(startTime)
    appLogger.log("(lantern-tunnel) stopTunnel completed in \(elapsed) seconds")
  }

  func opts() -> UtilsOpts {
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    opts.logDir = FilePath.logsDirectory.relativePath
    opts.deviceid = DeviceIdentifier.getUDID()
    opts.logLevel = "trace"
    opts.locale = Locale.current.identifier
    return opts
  }

  //Helper method to for platfrom interface to stop service
  private func stopService() {
    var error: NSError?
    MobileStopVPN(&error)
    if error != nil {
      appLogger.log("error while stopping tunnel \(error?.localizedDescription ?? "")")
    }
    postServiceClose()
  }

  func restartService() {
    appLogger.log("(lantern-tunnel) restarting service")
    reasserting = true
    defer {
      reasserting = false
    }
    stopService()

    // Don't cancelTunnelWithError on failure; this extension hosts the IPC server.
    var error: NSError?
    MobileStartVPN(&error)
    if let error {
      appLogger.log("(lantern-tunnel) restart failed: \(error.localizedDescription)")
      return
    }
    appLogger.log("(lantern-tunnel) tunnel restarted successfully")
  }

  func postServiceClose() {
    platformInterface.reset()
  }
}
