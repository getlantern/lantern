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

/// Coordinates connection changes while allowing stop to cancel a pending start.
actor VPNLifecycleCoordinator {
  private var nextConnectionID: UInt = 0
  private var activeConnectionID: UInt?
  private var stopPending = false
  private var stopWaiters: [CheckedContinuation<Void, Never>] = []

  /// Starts a connection operation unless another lifecycle change owns the manager.
  func beginConnectionOperation() throws -> UInt {
    guard activeConnectionID == nil, !stopPending else {
      throw VPNManagerError.operationInProgress
    }
    nextConnectionID &+= 1
    activeConnectionID = nextConnectionID
    return nextConnectionID
  }

  /// Returns false when a stop request has canceled this connection operation.
  func canContinueConnectionOperation(_ id: UInt) -> Bool {
    activeConnectionID == id && !stopPending
  }

  /// Hands the manager to a waiting stop request after startup work has finished.
  func endConnectionOperation(_ id: UInt) {
    guard activeConnectionID == id else { return }
    activeConnectionID = nil
    let waiters = stopWaiters
    stopWaiters.removeAll()
    waiters.forEach { $0.resume() }
  }

  /// Cancels any active connection operation and waits for its profile writes to finish.
  /// The return value tells the caller to tear down even if the system status has not caught up.
  func beginStopOperation() async throws -> Bool {
    guard !stopPending else {
      throw VPNManagerError.operationInProgress
    }
    stopPending = true
    let canceledConnectionOperation = activeConnectionID != nil
    guard canceledConnectionOperation else { return false }
    await withCheckedContinuation { continuation in
      stopWaiters.append(continuation)
    }
    return true
  }

  /// Allows connection changes again once the stop request has completed.
  func endStopOperation() {
    stopPending = false
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
