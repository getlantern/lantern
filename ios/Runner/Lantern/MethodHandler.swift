//
//  MethodHandler.swift
//  Lantern
//

import Flutter
import Foundation
import NetworkExtension

/// Handles Flutter method channel interactions for VPN operations.
class MethodHandler {

    private var channel: FlutterMethodChannel

    private var vpnManager: VPNManager

    init(channel: FlutterMethodChannel, vpnManager: VPNManager = VPNManager.shared) {
        self.channel = channel
        self.vpnManager = vpnManager
        setupMethodCallHandler()
    }

    /// Sets up the method call handler for the Flutter method channel.
    private func setupMethodCallHandler() {
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "startVPN":
                self.startVPN(result: result)
            case "stopVPN":
                self.stopVPN(result: result)
            case "isVPNConnected":
                self.isVPNConnected(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func startVPN(result: @escaping FlutterResult) {
        Task {
            do {
                try await vpnManager.startTunnel()
                await MainActor.run {
                    result("VPN started successfully.")
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "START_FAILED",
                                        message: "Unable to start VPN tunnel.",
                                        details: error.localizedDescription))
                }
            }
        }
    }

    private func stopVPN(result: @escaping FlutterResult) {
        Task {
            do {
                try await vpnManager.stopTunnel()
                await MainActor.run {
                    result("VPN stopped successfully.")
                }
            } catch {
                await MainActor.run {
                    result(FlutterError(code: "STOP_FAILED",
                                        message: "Unable to stop VPN tunnel.",
                                        details: error.localizedDescription))
                }
            }
        }
    }

    private func isVPNConnected(result: @escaping FlutterResult) {
        let status = vpnManager.connectionStatus
        let isConnected = status == .connected
        result(isConnected)
    }
}
