//
//  VPNBase.swift
//  Lantern
//

import NetworkExtension

enum VPNManagerError: Swift.Error {
  case userDisallowedVPNConfigurations
  case loadingProviderFailed
  case savingProviderFailed
  case unknown
}

protocol VPNBase: ObservableObject {
  var connectionStatus: NEVPNStatus { get }
  func startTunnel() async throws
  func stopTunnel() async throws
}
