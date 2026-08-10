//
//  Extension+RunBlocking.swift
//  SingBoxPacketTunnel
//
//  Created by GFWFighter on 7/25/1402 AP.
//

import Foundation
import NetworkExtension

/// Bound on every sync-over-async bridge below. Blocking a thread while awaiting a
/// continuation is exactly what Swift concurrency forbids: the continuation may need
/// a cooperative-pool thread that this wait is holding, and then nothing ever
/// signals. Without a deadline that wedges the extension permanently — a tunnel with
/// its routes installed and nothing servicing them. Generous, because the real work
/// here is milliseconds.
let runBlockingTimeout: DispatchTimeInterval = .seconds(15)

enum RunBlockingError: Error {
  /// The awaited work never completed. Treat as a failed operation, not a retryable
  /// stall: something upstream is wedged and the caller should tear down.
  case timedOut
}

/// Returns nil if the block did not finish within `runBlockingTimeout`.
func runBlocking<T>(_ block: @escaping () async -> T) -> T? {
  let semaphore = DispatchSemaphore(value: 0)
  let box = resultBox<T>()
  Task.detached {
    let value = await block()
    box.result0 = value
    semaphore.signal()
  }
  guard semaphore.wait(timeout: .now() + runBlockingTimeout) == .success else {
    return nil
  }
  return box.result0
}

func runBlocking<T>(_ tBlock: @escaping () async throws -> T) throws -> T {
  let semaphore = DispatchSemaphore(value: 0)
  let box = resultBox<T>()
  Task.detached {
    do {
      let value = try await tBlock()
      box.result = .success(value)
    } catch {
      box.result = .failure(error)
    }
    semaphore.signal()
  }
  guard semaphore.wait(timeout: .now() + runBlockingTimeout) == .success else {
    throw RunBlockingError.timedOut
  }
  return try box.result.get()
}

private class resultBox<T> {
  var result: Result<T, Error>!
  var result0: T!
}
