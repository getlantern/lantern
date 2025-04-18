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
    private var commandServer: LibboxCommandServer!
    private var boxService: LibboxBoxService!
    private var radiance: RadianceRadiance!
    private var systemProxyAvailable = false
    private var systemProxyEnabled = false
    private var platformInterface: ExtensionPlatformInterface!

    override open func startTunnel(options _: [String: NSObject]?) async throws {

        // NOTE: No need to call LibboxSetup here — Radiance handles global libbox setup internally.

        do {
            try FileManager.default.createDirectory(at: FilePath.sharedDirectory, withIntermediateDirectories: true)
        } catch {
            writeFatalError("(packet-tunnel) error: create shared directory: \(error.localizedDescription)")
            return
        }

        do {
            try FileManager.default.createDirectory(at: FilePath.workingDirectory, withIntermediateDirectories: true)
        } catch {
            writeFatalError("(packet-tunnel) error: create working directory: \(error.localizedDescription)")
            return
        }


        if platformInterface == nil {
            platformInterface = ExtensionPlatformInterface(self)
        }

        let maxLogLines = 50
        commandServer = LibboxNewCommandServer(platformInterface, Int32(maxLogLines))
        do {
            try commandServer.start()
        } catch {
            writeFatalError("(packet-tunnel): log server start error: \(error.localizedDescription)")
            return
        }

        var setupError: NSError?
        let baseDir = FilePath.sharedDirectory.relativePath
        let service = MobileSetupRadiance(baseDir, platformInterface, &setupError)
        if let setupError {
            writeFatalError("(packet-tunnel) error: setup radiance: \(setupError.localizedDescription)")
            return
        }

        guard let service else {
            return
        }

        radiance = service

        await startService()
    }

    func writeMessage(_ message: String) {
        if let commandServer {
            commandServer.writeMessage(message)
        }
    }

    public func writeFatalError(_ message: String) {
        #if DEBUG
            NSLog(message)
        #endif
        writeMessage(message)
        var error: NSError?
        LibboxWriteServiceError(message, &error)
        cancelTunnelWithError(nil)
    }

    #if os(macOS)

        private var locationManager: CLLocationManager?
        private var locationDelegate: stubLocationDelegate?

        class stubLocationDelegate: NSObject, CLLocationManagerDelegate {
            private unowned let radiance: Radiance
            init(_ radiance: Radiance) {
                self.radiance = radiance
            }

            func locationManagerDidChangeAuthorization(_: CLLocationManager) {
                //boxService.updateWIFIState()
            }

            func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}

            func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
        }

    #endif

    private func stopService() {
        var error: NSError?
        MobileStopVPN(&error)
        if let error {
            writeFatalError("(packet-tunnel) unable to stop VPN")
        }

        radiance = nil
        commandServer.setService(nil)

        if let platformInterface {
            platformInterface.reset()
        }
    }
    
    private func startService() async {
        var error: NSError?
        MobileStartVPN(&error)
        if let error {
            writeFatalError("(packet-tunnel) unable to start VPN")
        }
    }

    func reloadService() async {
        writeMessage("(packet-tunnel) reloading service")
        reasserting = true
        defer {
            reasserting = false
        }
        stopService()
        commandServer.resetLog()
        var error: NSError?
        MobileStartVPN(&error)
        if let error {
            writeFatalError("(packet-tunnel) unable to startVPN")
        }
    }

    func postServiceClose() {
        radiance = nil
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        writeMessage("(packet-tunnel) stopping, reason: \(reason)")
        stopService()
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
            try? server.close()
            commandServer = nil
        }
    }

    override open func handleAppMessage(_ messageData: Data) async -> Data? {
        messageData
    }

    override open func sleep() async {
        if let radiance {
            //radiance.pause()
        }
    }

    override open func wake() {
        if let radiance {
            //radiance.wake()
        }
    }
}
