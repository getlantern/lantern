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
import NetworkExtension
import OSLog

#if os(iOS)
  import WidgetKit
#endif
#if os(macOS)
  import CoreLocation
#endif

public class ExtensionProvider: NEPacketTunnelProvider {
  private var platformInterface: FFIPlatformInterface!

  override open func startTunnel(options: [String: NSObject]?) async throws {
    if platformInterface == nil {
      platformInterface = FFIPlatformInterface(self)
      platformInterface.registerCallbacks()
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
    cancelTunnelWithError(nil)
  }

  func startVPN(completion: ((Bool, String?) -> Void)? = nil) {
    appLogger.log("(lantern-tunnel) quick connect")

    let logDir = strdup(FilePath.logsDirectory.relativePath)
    let dataDir = strdup(FilePath.dataDirectory.relativePath)
    let locale = strdup(Locale.current.identifier)

    defer {
      free(logDir)
      free(dataDir)
      free(locale)
    }

    appLogger.info("Starting VPN with logDir: \(FilePath.logsDirectory.relativePath)")

    let result = startVPNWithPlatform(logDir, dataDir, locale)
    if let result = result {
      let resultString = String(cString: result)
      freeCString(result)

      if !resultString.isEmpty {
        appLogger.error("error while starting tunnel: \(resultString)")
        let error = NSError(
          domain: "org.getlantern.lantern.PacketTunnel",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: resultString]
        )
        cancelTunnelWithError(error)
        completion?(false, resultString)
        return
      }
    }

    appLogger.log("(lantern-tunnel) tunnel started successfully")
    completion?(true, nil)
  }

  func connectToServer(
    location: String, serverName: String, completion: ((Bool, String?) -> Void)? = nil
  ) {
    appLogger.log("(lantern-tunnel) connecting to server")

    let locationCStr = strdup(location)
    let serverNameCStr = strdup(serverName)
    let logDir = strdup(FilePath.logsDirectory.relativePath)
    let dataDir = strdup(FilePath.dataDirectory.relativePath)
    let locale = strdup(Locale.current.identifier)

    defer {
      free(locationCStr)
      free(serverNameCStr)
      free(logDir)
      free(dataDir)
      free(locale)
    }

    let result = connectToServerWithPlatform(locationCStr, serverNameCStr, logDir, dataDir, locale)
    if let result = result {
      let resultString = String(cString: result)
      freeCString(result)

      if !resultString.isEmpty {
        appLogger.error("error while connecting to server: \(resultString)")
        let error = NSError(
          domain: "org.getlantern.lantern.PacketTunnel",
          code: -1,
          userInfo: [NSLocalizedDescriptionKey: resultString]
        )
        cancelTunnelWithError(error)
        completion?(false, resultString)
        return
      }
    }

    appLogger.log("(lantern-tunnel) connected to server successfully")
    completion?(true, nil)
  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
    appLogger.log("(lantern-tunnel) stopping, reason:\(String(describing: reason))")

    let result = stopVPN()
    if let result = result {
      let resultString = String(cString: result)
      freeCString(result)

      if !resultString.isEmpty {
        appLogger.log("error while stopping tunnel: \(resultString)")
        return
      }
    }

    appLogger.log("(lantern-tunnel) tunnel closed")
    platformInterface.reset()

    #if os(macOS)
      // HACK: There is a bug in the NetworkExtension code so it doesn't reliably teardown
      // and terminate the extension process on return -- causing the tunnel to remain in
      // memory or stuck in an inconsistent state.
      // see https://github.com/WireGuard/wireguard-apple/blob/master/Sources/WireGuardNetworkExtension/PacketTunnelProvider.swift#L83-L88
      exit(0)
    #endif
  }

  private func stopService() {
    appLogger.info("ExtensionProvider stopService")

    let result = stopVPN()
    if let result = result {
      let resultString = String(cString: result)
      freeCString(result)

      if !resultString.isEmpty {
        appLogger.log("error while stopping tunnel: \(resultString)")
      }
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
    startVPN()
  }

  func postServiceClose() {
    platformInterface.reset()
  }
}
