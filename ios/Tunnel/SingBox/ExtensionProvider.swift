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

  /// Whether a tunnel bring-up has been attempted and not yet torn down.
  ///
  /// The extension process outlives the app, so this survives an app quit —
  /// unlike any state the app holds. Guarded because `startTunnel` and
  /// `stopTunnel` arrive on NetworkExtension's queue while `restartService`
  /// arrives on a libbox thread.
  private let tunnelStateQueue = DispatchQueue(
    label: "org.getlantern.lantern.Tunnel.tunnelState")
  private var _tunnelIsRunning = false

  /// Marks a bring-up as starting and reports whether one was already live.
  /// Test and set are atomic so two starts cannot both see "nothing running".
  private func claimTunnel() -> Bool {
    tunnelStateQueue.sync {
      let wasRunning = _tunnelIsRunning
      _tunnelIsRunning = true
      return wasRunning
    }
  }

  private func setTunnelRunning(_ running: Bool) {
    tunnelStateQueue.sync { _tunnelIsRunning = running }
  }

  override open func startTunnel(options: [String: NSObject]?) async throws {
    if platformInterface == nil {
      platformInterface = ExtensionPlatformInterface(self)
    }

    // A start can arrive while the previous tunnel is still up: the extension
    // process outlives the app, so a force-quit without disconnecting — or an
    // app-side stop that no-ops on a stale NEVPNStatus — leaves it running.
    // Starting on top leaves the old utun open, and openTun's fallback then
    // hands the new sing-box the lowest-numbered utun in the process (the dead
    // one) while the system routes traffic to the new interface. Every packet
    // is blackholed until the extension process is killed, which is why
    // reporters find that only a reboot fixes it (getlantern/engineering#3781).
    //
    // Claimed before the bring-up rather than after: a start that fails partway
    // can still have opened a utun.
    if claimTunnel() {
      appLogger.info("(lantern-tunnel) start arrived with a live tunnel; stopping it first")
      stopService()
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
    // it may begin before this returns, it just cannot delay the return. The
    // system tears the tunnel down while startTunnel is still outstanding
    // (getlantern/engineering#3822). Nothing reached the system from here
    // anyway: startVPN reports its own failures via cancelTunnelWithError.
    //
    // That budget is measured, not documented. Apple publishes no startTunnel
    // completion deadline, and the teardowns never called stopTunnel(with:), so no
    // NEProviderStopReason was captured. The evidence is 14 system-initiated
    // teardowns in one CN session, none app-requested, median 7.51s. Returning
    // promptly does not depend on the figure — only on the budget being finite
    // and shorter than the work.
    //
    // Returning marks the provider started, but no tunnel settings exist until
    // the connect below applies them, so the system claims no routes and
    // traffic still egresses directly. Reassert until the connect finishes so
    // the OS does not report a working VPN over a window that, on a first run
    // with no cached config, lasts as long as the config fetch.
    reasserting = true

    let tunnelType = options?["netEx.Type"] as? String
    let serverName = options?["netEx.ServerName"] as? String
    Task.detached { [weak self] in
      guard let self else { return }
      defer { self.reasserting = false }
      switch tunnelType {
      case "PrivateServer":
        guard let serverName else {
          self.writeFatalError("Missing netEx.ServerName")
          return
        }
        self.connectToServer(serverName: serverName)
      default:
        self.startVPN()
      }
    }
  }

  public func writeFatalError(_ message: String) {
    appLogger.error("\(message)")
    let error = NSError(
      domain: "org.getlantern.lantern.packettunnel",
      code: 1,
      userInfo: [NSLocalizedDescriptionKey: message]
    )
    cancelTunnelWithError(error)
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
    // Intentionally left empty. The app and extension don't share a keychain access
    // Radiance resolves the device ID from the main app process.
    opts.deviceid = ""
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
    setTunnelRunning(false)
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
    setTunnelRunning(true)
    appLogger.log("(lantern-tunnel) tunnel restarted successfully")
  }

  func postServiceClose() {
    platformInterface.reset()
  }
}
