//
//  VPNBase.swift
//  Lantern
//

import Foundation
import NetworkExtension

enum VPNManagerError: LocalizedError, Equatable {
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

/// Prevents two VPN lifecycle operations from running at the same time.
final class VPNOperationGate {
  private let lock = NSLock()
  private var active = false

  /// Claims the gate or reports that another operation is still running.
  func begin() throws {
    lock.lock()
    defer { lock.unlock() }
    guard !active else {
      throw VPNManagerError.operationInProgress
    }
    active = true
  }

  /// Releases the gate after the current operation finishes.
  func end() {
    lock.lock()
    active = false
    lock.unlock()
  }
}

/// Returns whether a new tunnel should start for the current system status.
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

/// Returns whether the current tunnel should be stopped.
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
