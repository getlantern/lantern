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

open class ExtensionProvider: NEPacketTunnelProvider {
    private var radiance: RadianceRadiance!
    private var platformInterface: ExtensionPlatformInterface!

    override open func startTunnel(options _: [String: NSObject]?) async throws {

        let ignoreMemoryLimit = false // !SharedPreferences.ignoreMemoryLimit.get()
        LibboxSetMemoryLimit(!ignoreMemoryLimit)

        if platformInterface == nil {
            platformInterface = ExtensionPlatformInterface(self)
        }

        writeMessage("(lantern-tunnel): Here I stand")
        await startService()
    }

    func writeMessage(_ message: String) {
        #if DEBUG
            NSLog(message)
        #endif
    }

    public func writeFatalError(_ message: String) {
        writeMessage(message)
        var error: NSError?
        LibboxWriteServiceError(message, &error)
        cancelTunnelWithError(nil)
    }

    private func startService() async {
        var error: NSError?
        let baseDir = FilePath.workingDirectory.relativePath
        let service = MobileSetupRadiance(baseDir, platformInterface, &error)
        if let error {
            writeFatalError("(lantern-tunnel) error: create service: \(error.localizedDescription)")
            return
        }
        guard let service else {
            return
        }
        do {
            try service.startVPN()
        } catch {
            writeFatalError("(lantern-tunnel) error: start radiance: \(error.localizedDescription)")
            return
        }
        radiance = service
    }

    private func stopService() {
        if let service = radiance {
            do {
                try radiance.stopVPN()
            } catch {
                writeMessage("(lantern-tunnel) error: stop service: \(error.localizedDescription)")
            }
            radiance = nil
        }
        if let platformInterface {
            platformInterface.reset()
        }
    }

    func reloadService() async {
        writeMessage("(lantern-tunnel) reloading service")
        reasserting = true
        defer {
            reasserting = false
        }
        stopService()
        await startService()
    }

    func postServiceClose() {
        radiance = nil
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        writeMessage("(lantern-tunnel) stopping, reason: \(reason)")
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
