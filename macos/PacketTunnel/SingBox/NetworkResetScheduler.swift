import Foundation

final class NetworkResetScheduler {
  final class Session {}

  private let lock = NSLock()
  private let queue: DispatchQueue
  private var session: Session?
  private var pending: DispatchWorkItem?

  init(queue: DispatchQueue = DispatchQueue(label: "org.getlantern.PacketTunnel.networkReset")) {
    self.queue = queue
  }

  func startSession() -> Session {
    lock.lock()
    defer { lock.unlock() }
    pending?.cancel()
    pending = nil
    let session = Session()
    self.session = session
    return session
  }

  func isCurrent(_ session: Session) -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return self.session === session
  }

  func schedule(
    for session: Session, after delay: DispatchTimeInterval, reset: @escaping () -> Void
  ) {
    lock.lock()
    defer { lock.unlock() }
    guard self.session === session else { return }
    pending?.cancel()
    let work = DispatchWorkItem { [weak self] in
      guard let self, self.isCurrent(session) else { return }
      // The reset must also check its target in Go, where tunnel replacement is locked.
      reset()
    }
    pending = work
    queue.asyncAfter(deadline: .now() + delay, execute: work)
  }

  func cancelPending(for session: Session) {
    lock.lock()
    defer { lock.unlock() }
    guard self.session === session else { return }
    pending?.cancel()
    pending = nil
  }

  func endSession(_ session: Session? = nil) {
    lock.lock()
    defer { lock.unlock() }
    if let session, self.session !== session { return }
    self.session = nil
    pending?.cancel()
    pending = nil
  }

  // Call before stopping Go's tunnel. Waiting from a Go monitor-close callback
  // could deadlock with a reset waiting for the tunnel's lock.
  func endSessionAndWait() {
    endSession()
    queue.sync {}
  }
}
