//
//  PacketTunnelProvider.swift
//  LanternTunnel
//

import NetworkExtension
import System
import os

class PacketTunnelProvider: ExtensionProvider {
    override func startTunnel(options: [String: NSObject]?) async throws {
        try await super.startTunnel(options: options)
    }
}
