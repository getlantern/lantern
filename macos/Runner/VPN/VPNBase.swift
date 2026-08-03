//
//  VPNBase.swift
//  Lantern
//

import NetworkExtension

enum VPNManagerError: LocalizedError {
  case userDisallowedVPNConfigurations
  case loadingProviderFailed
  case savingProviderFailed
  case operationInProgress
  case unknown

  var errorDescription: String? {
    switch self {
    case .userDisallowedVPNConfigurations:
      return "VPN configurations are not allowed."
    case .loadingProviderFailed:
      return "Unable to load the VPN configuration."
    case .savingProviderFailed:
      return "Unable to save the VPN configuration."
    case .operationInProgress:
      return "A VPN operation is already in progress."
    case .unknown:
      return "An unknown VPN error occurred."
    }
  }
}

func shouldStartNewTunnel(for status: NEVPNStatus) throws -> Bool {
  switch status {
  case .connected:
    return false
  case .disconnected:
    return true
  case .connecting, .disconnecting, .reasserting:
    throw VPNManagerError.operationInProgress
  case .invalid:
    throw VPNManagerError.loadingProviderFailed
  @unknown default:
    throw VPNManagerError.unknown
  }
}

func shouldStopTunnel(for status: NEVPNStatus) throws -> Bool {
  switch status {
  case .connected, .connecting, .reasserting:
    return true
  case .disconnected, .disconnecting:
    return false
  case .invalid:
    throw VPNManagerError.loadingProviderFailed
  @unknown default:
    throw VPNManagerError.unknown
  }
}

protocol VPNBase: ObservableObject {
  var connectionStatus: NEVPNStatus { get }
  func startTunnel() async throws
  func stopTunnel() async throws
}
