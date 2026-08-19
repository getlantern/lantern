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

    // Start the IPC server before any VPN operations
    var ipcError: NSError?
    MobileStartIPCServer(platformInterface, opts(), &ipcError)
    if let ipcError {
      appLogger.error("error starting IPC server: \(ipcError.localizedDescription)")
      throw ipcError
    }

    // Bringing the VPN up now waits for the first config, which takes seconds
    // on a censored network, so the connect is dispatched rather than awaited —
    // it may begin before this returns, it just cannot hold the system's start
    // call open (getlantern/engineering#3822). Nothing reached the system from
    // here anyway: startVPN reports its own failures via cancelTunnelWithError.
    //
    // Returning marks the provider started, but no tunnel settings exist until
    // the connect below applies them, so the system claims no routes and
    // traffic still egresses directly. Reassert until the connect finishes so
    // the OS does not report a working VPN over that window.
    reasserting = true

    let tunnelType = options?["netEx.Type"] as? String
    let serverName = options?["netEx.ServerName"] as? String
    Task.detached { [weak self] in
      guard let self else { return }
      defer { self.reasserting = false }
      switch tunnelType {
      case "Lantern":
        appLogger.info("(lantern-tunnel) user initiated connection")
        self.startVPN()
      case "PrivateServer":
        guard let serverName else {
          self.writeFatalError("Missing netEx.ServerName")
          return
        }
        self.connectToServer(serverName: serverName)
      default:
        // Fallback or unknown type
        appLogger.info("(lantern-tunnel) unknown tunnel type \(String(describing: tunnelType))")
        self.startVPN()
      }
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

    MobileStartVPN(&error)
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
    serverName: String, completion: ((Bool, String?) -> Void)? = nil
  ) {
    appLogger.log("(lantern-tunnel) connecting to server")
    var error: NSError?
    MobileConnectToServer(serverName, &error)
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
    }
    MobileCloseIPCServer(&error)
    if error != nil {
      appLogger.log("error closing IPC server \(error?.localizedDescription ?? "")")
    }
    appLogger.log("(lantern-tunnel) tunnel closed")
    platformInterface.reset()
  }

  private func stopService() {
    appLogger.info("ExtensionProvider stopService")
    var error: NSError?
    MobileStopVPN(&error)
    if error != nil {
      appLogger.log("error while stopping tunnel \(error?.localizedDescription ?? "")")
    }
    postServiceClose()
  }

  func restartService() throws {
    appLogger.log("(lantern-tunnel) restarting service")
    reasserting = true
    defer {
      reasserting = false
    }
    stopService()

    var error: NSError?
    MobileStartVPN(&error)
    if let error {
      appLogger.error("(lantern-tunnel) restart failed: \(error.localizedDescription)")
      // A failed (re)start must tear the tunnel down so on-demand/the app can recover
      // rather than leaving a dead-but-"connected" tunnel; the throw propagates the
      // failure to radiance's Restart so it reports ErrorStatus instead of success.
      cancelTunnelWithError(error)
      throw error
    }
    appLogger.log("(lantern-tunnel) tunnel restarted successfully")
  }

  func postServiceClose() {
    platformInterface.reset()
  }

  func opts() -> UtilsOpts {
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    // opts.deviceid = DeviceIdentifier.getUDID()
    opts.appVersion =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    opts.locale = Locale.current.identifier
    opts.logLevel = "trace"
    opts.logDir = FilePath.logsDirectory.relativePath
    appLogger.info("logging to \(opts.logDir)")
    return opts
  }
}
