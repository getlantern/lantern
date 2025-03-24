//
//  NetworkUtils.swift
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
    public var username: String? = nil
    private var commandServer: LibboxCommandServer!
    private var boxService: LibboxBoxService!
    private var systemProxyAvailable = false
    private var systemProxyEnabled = false
    private var platformInterface: ExtensionPlatformInterface!

    override open func startTunnel(options _: [String: NSObject]?) async throws {
        LibboxClearServiceError()

        let options = LibboxSetupOptions()
        options.basePath = FilePath.sharedDirectory.relativePath
        options.workingPath = FilePath.workingDirectory.relativePath
        options.tempPath = FilePath.cacheDirectory.relativePath
        var error: NSError?
        #if os(tvOS)
            options.isTVOS = true
        #endif
        if let username {
            options.username = username
        }
        LibboxSetup(options, &error)
        if let error {
            writeFatalError("(packet-tunnel) error: setup service: \(error.localizedDescription)")
            return
        }

        LibboxRedirectStderr(FilePath.cacheDirectory.appendingPathComponent("stderr.log").relativePath, &error)
        if let error {
            writeFatalError("(packet-tunnel) redirect stderr error: \(error.localizedDescription)")
            return
        }

        await LibboxSetMemoryLimit(!SharedPreferences.ignoreMemoryLimit.get())

        if platformInterface == nil {
            platformInterface = ExtensionPlatformInterface(self)
        }
        commandServer = await LibboxNewCommandServer(platformInterface, Int32(SharedPreferences.maxLogLines.get()))
        do {
            try commandServer.start()
        } catch {
            writeFatalError("(packet-tunnel): log server start error: \(error.localizedDescription)")
            return
        }
        writeMessage("(packet-tunnel): Here I stand")
        await startService()
        #if os(iOS)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadControls(ofKind: ExtensionProfile.controlKind)
            }
        #endif
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

    private func startService() async {
        let profile: Profile?
        do {
            profile = try await ProfileManager.get(Int64(SharedPreferences.selectedProfileID.get()))
        } catch {
            writeFatalError("(packet-tunnel) error: read selected profile: \(error.localizedDescription)")
            return
        }
        guard let profile else {
            writeFatalError("(packet-tunnel) error: missing selected profile")
            return
        }
        let configContent: String
        do {
            configContent = try profile.read()
        } catch {
            writeFatalError("(packet-tunnel) error: read config file \(profile.path): \(error.localizedDescription)")
            return
        }
        var error: NSError?
        let service = LibboxNewService(configContent, platformInterface, &error)
        if let error {
            writeFatalError("(packet-tunnel) error: create service: \(error.localizedDescription)")
            return
        }
        guard let service else {
            return
        }
        do {
            try service.start()
        } catch {
            writeFatalError("(packet-tunnel) error: start service: \(error.localizedDescription)")
            return
        }
        commandServer.setService(service)
        boxService = service
        #if os(macOS)
            await SharedPreferences.startedByUser.set(true)
            if service.needWIFIState() {
                if !Variant.useSystemExtension {
                    locationManager = CLLocationManager()
                    locationDelegate = stubLocationDelegate(boxService)
                    locationManager?.delegate = locationDelegate
                    locationManager?.requestLocation()
                } else {
                    commandServer.writeMessage("(packet-tunnel) WIFI SSID and BSSID information is not currently available in the standalone version of SFM. We are working on resolving this issue.")
                }
            }
        #endif
    }

    #if os(macOS)

        private var locationManager: CLLocationManager?
        private var locationDelegate: stubLocationDelegate?

        class stubLocationDelegate: NSObject, CLLocationManagerDelegate {
            private unowned let boxService: LibboxBoxService
            init(_ boxService: LibboxBoxService) {
                self.boxService = boxService
            }

            func locationManagerDidChangeAuthorization(_: CLLocationManager) {
                boxService.updateWIFIState()
            }

            func locationManager(_: CLLocationManager, didUpdateLocations _: [CLLocation]) {}

            func locationManager(_: CLLocationManager, didFailWithError _: Error) {}
        }

    #endif

    private func stopService() {
        if let service = boxService {
            do {
                try service.close()
            } catch {
                writeMessage("(packet-tunnel) error: stop service: \(error.localizedDescription)")
            }
            boxService = nil
            commandServer.setService(nil)
        }
        if let platformInterface {
            platformInterface.reset()
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
        await startService()
    }

    func postServiceClose() {
        boxService = nil
    }

    override open func stopTunnel(with reason: NEProviderStopReason) async {
        writeMessage("(packet-tunnel) stopping, reason: \(reason)")
        stopService()
        if let server = commandServer {
            try? await Task.sleep(nanoseconds: 100 * NSEC_PER_MSEC)
            try? server.close()
            commandServer = nil
        }
        #if os(macOS)
            if reason == .userInitiated {
                await SharedPreferences.startedByUser.set(reason == .userInitiated)
            }
        #endif
        #if os(iOS)
            if #available(iOS 18.0, *) {
                ControlCenter.shared.reloadControls(ofKind: ExtensionProfile.controlKind)
            }
        #endif
    }

    override open func handleAppMessage(_ messageData: Data) async -> Data? {
        messageData
    }

    override open func sleep() async {
        if let boxService {
            boxService.pause()
        }
    }

    override open func wake() {
        if let boxService {
            boxService.wake()
        }
    }
}
