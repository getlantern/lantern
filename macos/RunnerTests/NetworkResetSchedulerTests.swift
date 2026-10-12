import Foundation
import XCTest

final class NetworkResetSchedulerTests: XCTestCase {
  private final class Resets {
    private let lock = NSLock()
    private var recorded: [String] = []

    func append(_ value: String) {
      lock.lock()
      recorded.append(value)
      lock.unlock()
    }

    var values: [String] {
      lock.lock()
      defer { lock.unlock() }
      return recorded
    }
  }

  private func blockedQueue() -> (DispatchQueue, DispatchSemaphore) {
    let queue = DispatchQueue(label: "NetworkResetSchedulerTests.reset")
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    queue.async {
      started.signal()
      release.wait()
    }
    XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
    return (queue, release)
  }

  func testQueuedResetCannotAffectReplacementSession() {
    for endFirst in [false, true] {
      let (queue, release) = blockedQueue()
      defer { release.signal() }
      let scheduler = NetworkResetScheduler(queue: queue)
      let resets = Resets()
      let old = scheduler.startSession()
      scheduler.schedule(for: old, after: .nanoseconds(0)) { resets.append("old") }

      if endFirst { scheduler.endSession() }
      let replacement = scheduler.startSession()
      let completed = expectation(description: "replacement reset, endFirst=\(endFirst)")
      scheduler.schedule(for: replacement, after: .nanoseconds(0)) {
        resets.append("replacement")
        completed.fulfill()
      }
      release.signal()
      wait(for: [completed], timeout: 5)
      queue.sync {}

      XCTAssertEqual(resets.values, ["replacement"])
      XCTAssertFalse(scheduler.isCurrent(old))
      XCTAssertTrue(scheduler.isCurrent(replacement))
    }
  }

  func testPendingResetsCoalesce() {
    let (queue, release) = blockedQueue()
    defer { release.signal() }
    let scheduler = NetworkResetScheduler(queue: queue)
    let session = scheduler.startSession()
    let resets = Resets()
    let completed = expectation(description: "latest reset")
    scheduler.schedule(for: session, after: .nanoseconds(0)) { resets.append("first") }
    scheduler.schedule(for: session, after: .nanoseconds(0)) {
      resets.append("latest")
      completed.fulfill()
    }
    release.signal()
    wait(for: [completed], timeout: 5)
    queue.sync {}

    XCTAssertEqual(resets.values, ["latest"])
  }

  func testCancelPendingKeepsSessionActive() {
    let (queue, release) = blockedQueue()
    defer { release.signal() }
    let scheduler = NetworkResetScheduler(queue: queue)
    let session = scheduler.startSession()
    let resets = Resets()
    scheduler.schedule(for: session, after: .nanoseconds(0)) { resets.append("cancelled") }
    scheduler.cancelPending(for: session)
    let completed = expectation(description: "worker drained")
    queue.async { completed.fulfill() }
    release.signal()
    wait(for: [completed], timeout: 5)
    queue.sync {}

    XCTAssertEqual(resets.values, [])
    XCTAssertTrue(scheduler.isCurrent(session))
  }

  func testLateOldSessionWorkCannotCancelReplacementReset() {
    let (queue, release) = blockedQueue()
    defer { release.signal() }
    let scheduler = NetworkResetScheduler(queue: queue)
    let old = scheduler.startSession()
    scheduler.endSession()
    let replacement = scheduler.startSession()
    let resets = Resets()
    let completed = expectation(description: "replacement reset")
    scheduler.schedule(for: replacement, after: .nanoseconds(0)) {
      resets.append("replacement")
      completed.fulfill()
    }
    scheduler.schedule(for: old, after: .nanoseconds(0)) { resets.append("old") }
    scheduler.cancelPending(for: old)
    release.signal()
    wait(for: [completed], timeout: 5)
    queue.sync {}

    XCTAssertEqual(resets.values, ["replacement"])
    XCTAssertTrue(scheduler.isCurrent(replacement))
  }

  func testEndSessionDoesNotWaitForRunningReset() {
    let scheduler = NetworkResetScheduler()
    let session = scheduler.startSession()
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    defer { release.signal() }
    scheduler.schedule(for: session, after: .nanoseconds(0)) {
      started.signal()
      release.wait()
    }
    XCTAssertEqual(started.wait(timeout: .now() + 5), .success)

    let ended = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      scheduler.endSession()
      ended.signal()
    }
    XCTAssertEqual(ended.wait(timeout: .now() + 5), .success)
    XCTAssertFalse(scheduler.isCurrent(session))
    release.signal()
    scheduler.endSessionAndWait()
  }

  func testEndSessionAndWaitDrainsRunningResetBeforeReplacement() {
    let scheduler = NetworkResetScheduler()
    let session = scheduler.startSession()
    let started = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let resetFinished = DispatchSemaphore(value: 0)
    defer { release.signal() }
    scheduler.schedule(for: session, after: .nanoseconds(0)) {
      started.signal()
      release.wait()
      resetFinished.signal()
    }
    XCTAssertEqual(started.wait(timeout: .now() + 5), .success)
    scheduler.endSession()

    let ended = DispatchSemaphore(value: 0)
    let draining = DispatchSemaphore(value: 0)
    let completed = expectation(description: "replacement reset")
    DispatchQueue.global().async {
      draining.signal()
      scheduler.endSessionAndWait()
      XCTAssertEqual(resetFinished.wait(timeout: .now()), .success)
      let replacement = scheduler.startSession()
      scheduler.schedule(for: replacement, after: .nanoseconds(0)) { completed.fulfill() }
      ended.signal()
    }
    XCTAssertEqual(draining.wait(timeout: .now() + 5), .success)
    XCTAssertEqual(ended.wait(timeout: .now() + .milliseconds(50)), .timedOut)
    release.signal()
    wait(for: [completed], timeout: 5)
    XCTAssertEqual(ended.wait(timeout: .now() + 5), .success)
    XCTAssertFalse(scheduler.isCurrent(session))
  }
}
