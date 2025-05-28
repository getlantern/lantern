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

class ExtensionProvider: NEPacketTunnelProvider {
    let appLogger = Logger(subsystem: "org.getlantern.lantern", category: "ExtensionProvider")
  private var platformInterface: ExtensionPlatformInterface!

  override open func startTunnel(options _: [String: NSObject]?) async throws {
    let ignoreMemoryLimit = false
    LibboxSetMemoryLimit(!ignoreMemoryLimit)
    if platformInterface == nil {
      platformInterface = ExtensionPlatformInterface(self)
    }
    startService()
  }

  public func writeFatalError(_ message: String) {
      appLogger.error("\(String(describing: message))")
    var error: NSError?
    LibboxWriteServiceError(message, &error)
    cancelTunnelWithError(nil)
  }

  private func startService() {
    var error: NSError?
    let baseDir = FilePath.workingDirectory.relativePath
    let opts = MobileOpts()
    opts.dataDir = baseDir
    opts.deviceid = DeviceIdentifier.getUDID()
    opts.locale = Locale.current.identifier
    MobileNewVPNClient(opts, platformInterface, &error)
    if let error {
      writeFatalError("(lantern-tunnel) error: create service: \(error.localizedDescription)")
      return
    }
    MobileStartVPN(&error)
    if error != nil {
      appLogger.error("error while starting tunnel \(error?.localizedDescription ?? "")")

    }
  }

  private func stopService() {
    var error: NSError?
    MobileStopVPN(&error)
    if error != nil {
      appLogger.log("error while stopping tunnel \(error?.localizedDescription ?? "")")
      return
    }
    platformInterface.reset()

  }

  func reloadService() {
    appLogger.log("(lantern-tunnel) reloading service")
    reasserting = true
    defer {
      reasserting = false
    }
    stopService()
    startService()
  }

  func postServiceClose() {
    //    radiance = nil
  }

  override open func stopTunnel(with reason: NEProviderStopReason) async {
      appLogger.error("\(String(describing: "Stopping tunnel with reason: \(reason)"))")
      stopService()
  }

  override open func handleAppMessage(_ messageData: Data) async -> Data? {
    messageData
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
}
