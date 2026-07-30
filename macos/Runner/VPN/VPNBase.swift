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

enum VPNConnectionAction: Equatable {
  case startTunnel
  case sendCommandToExtension
}

func vpnConnectionAction(for status: NEVPNStatus) throws -> VPNConnectionAction {
  switch status {
  case .connected:
    return .sendCommandToExtension
  case .disconnected:
    return .startTunnel
  case .connecting, .disconnecting, .reasserting:
    throw VPNManagerError.operationInProgress
  case .invalid:
    throw VPNManagerError.loadingProviderFailed
  @unknown default:
    throw VPNManagerError.unknown
  }
}

enum VPNStopAction: Equatable {
  case stopTunnel
  case alreadyStopped
}

func vpnStopAction(for status: NEVPNStatus) throws -> VPNStopAction {
  switch status {
  case .connected, .connecting, .reasserting:
    return .stopTunnel
  case .disconnected, .disconnecting:
    return .alreadyStopped
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
