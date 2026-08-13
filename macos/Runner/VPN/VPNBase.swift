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
  private struct StopWaiter {
    let connectionID: UInt
    let continuation: CheckedContinuation<Void, Never>
  }

  private var nextConnectionID: UInt = 0
  private var activeConnectionID: UInt?
  private var stopPending = false
  private var stopWaiter: StopWaiter?
  private var stopHandoffTimeoutTask: Task<Void, Never>?
  private let stopHandoffTimeoutNanoseconds: UInt64

  init(stopHandoffTimeoutNanoseconds: UInt64 = 5_000_000_000) {
    self.stopHandoffTimeoutNanoseconds = stopHandoffTimeoutNanoseconds
  }

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

  /// Performs the final synchronous connection transition while this actor
  /// still owns the lifecycle decision, so a stop cannot interleave between
  /// the cancellation check and starting the system tunnel.
  func performFinalConnectionTransition<T>(
    _ id: UInt,
    _ transition: () throws -> T
  ) throws -> T {
    guard activeConnectionID == id, !stopPending else {
      throw VPNManagerError.operationInProgress
    }
    return try transition()
  }

  /// Hands the manager to a waiting stop request after startup work has finished.
  func endConnectionOperation(_ id: UInt) {
    guard activeConnectionID == id else { return }
    activeConnectionID = nil
    finishStopHandoff(for: id)
  }

  /// Cancels any active connection operation and briefly waits for it to hand off the manager.
  /// The return value tells the caller to tear down even if the system status has not caught up.
  func beginStopOperation() async throws -> Bool {
    guard !stopPending else {
      throw VPNManagerError.operationInProgress
    }
    stopPending = true
    guard let connectionID = activeConnectionID else { return false }
    let timeout = stopHandoffTimeoutNanoseconds

    await withCheckedContinuation { continuation in
      stopWaiter = StopWaiter(connectionID: connectionID, continuation: continuation)
      stopHandoffTimeoutTask = Task { [weak self] in
        do {
          try await Task.sleep(nanoseconds: timeout)
        } catch {
          return
        }
        await self?.expireStopHandoff(for: connectionID)
      }
    }
    return true
  }

  /// Allows connection changes again once the stop request has completed.
  func endStopOperation() {
    stopPending = false
  }

  private func finishStopHandoff(for connectionID: UInt) {
    guard let waiter = stopWaiter, waiter.connectionID == connectionID else { return }
    stopWaiter = nil
    stopHandoffTimeoutTask?.cancel()
    stopHandoffTimeoutTask = nil
    waiter.continuation.resume()
  }

  private func expireStopHandoff(for connectionID: UInt) {
    guard let waiter = stopWaiter, waiter.connectionID == connectionID else { return }
    stopWaiter = nil
    stopHandoffTimeoutTask = nil
    if activeConnectionID == connectionID {
      activeConnectionID = nil
    }
    waiter.continuation.resume()
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
  case .disconnected, .disconnecting, .invalid:
    return false
  @unknown default:
    throw VPNManagerError.unknown
  }
}

protocol VPNBase: ObservableObject {
  var connectionStatus: NEVPNStatus { get }
  func startTunnel() async throws
  func stopTunnel() async throws
}
