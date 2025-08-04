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
import CoreLocation


class ExtensionProvider: NEPacketTunnelProvider {
  private var platformInterface: ExtensionPlatformInterface!

  override open func startTunnel(options: [String: NSObject]?) async throws {
    tunnelLogger.info("startTunnel called with options: \(String(describing: options))")

    if platformInterface == nil {
      tunnelLogger.debug("Initializing platform interface")
      platformInterface = ExtensionPlatformInterface(self)
    }

    let tunnelType = options?["netEx.Type"] as? String
    tunnelLogger.info("Tunnel type: \(String(describing: tunnelType))")

    switch tunnelType {
    case "User":
      tunnelLogger.debug("Starting user tunnel")
      startVPN()
    case "PrivateServer":
      let serverName = options?["netEx.ServerName"] as? String
      let location = options?["netEx.Location"] as? String

      guard let location = location, let serverName = serverName else {
        tunnelLogger.error("Missing serverName or location for PrivateServer tunnel")
        return
      }

      tunnelLogger.debug(
        "Connecting to private server - Name: \(serverName), Location: \(location)")
      connectToServer(location: location, serverName: serverName)
    default:
      tunnelLogger.error(
        "Unknown tunnel type '\(String(describing: tunnelType))', falling back to user tunnel")
      startVPN()
    }
  }

  public func writeFatalError(_ message: String) {
    tunnelLogger.error("Fatal error: \(message)")
    var error: NSError?
    LibboxWriteServiceError(message, &error)
    cancelTunnelWithError(nil)
  }

  func startVPN() {
    tunnelLogger.info("Starting VPN")
    var error: NSError?
    MobileStartVPN(platformInterface, opts(), &error)

    if let err = error {
      tunnelLogger.error("Failed to start VPN: \(err.localizedDescription)")
      cancelTunnelWithError(err)
      return
    }
    tunnelLogger.info("Tunnel started successfully")
  }

  func connectToServer(location: String, serverName: String) {
    tunnelLogger.info("Connecting to server \(serverName) at location \(location)")
    var error: NSError?
    MobileConnectToServer(location, serverName, platformInterface, opts(), &error)

    if let err = error {
      tunnelLogger.error("Failed to connect to server: \(err.localizedDescription)")
      cancelTunnelWithError(err)
      return
    }

    tunnelLogger.info("Connected to server successfully")
  }

  private func stopService() {
    tunnelLogger.info("Stopping VPN service")
    var error: NSError?
    MobileStopVPN(&error)

    if let err = error {
      tunnelLogger.error("Error while stopping tunnel: \(err.localizedDescription)")
    } else {
      tunnelLogger.info("VPN stopped successfully")
    }

    platformInterface.reset()
  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
    tunnelLogger.info("stopTunnel called with reason: \(reason.rawValue)")
    stopService()
  }

  func opts() -> UtilsOpts {
    let baseDir = FilePath.sharedDirectory.relativePath
    tunnelLogger.debug("Tunnel options - dataDir: \(baseDir), locale: \(Locale.current.identifier)")

    let opts = UtilsOpts()
    opts.dataDir = baseDir
    opts.locale = Locale.current.identifier

    return opts
  }
}
