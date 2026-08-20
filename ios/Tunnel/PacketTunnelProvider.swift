//
//  PacketTunnelProvider.swift
//  LanternTunnel
//

import Darwin
import NetworkExtension
import System
import os

class PacketTunnelProvider: ExtensionProvider {
  private var memoryLogTimer: DispatchSourceTimer?
  private var memoryPressureSource: DispatchSourceMemoryPressure?
  private var currentMemoryPressure: DispatchSource.MemoryPressureEvent = .normal
  private var memorySampleCount = 0
  private var lastMemoryLog: Date?

  // A tunnel torn down seconds after start used to leave a single sample, so a
  // footprint climbing toward the jetsam cap was indistinguishable from a flat
  // one. Sample every second and throttle the log instead (cf. radiance memmon).
  private static let memorySampleInterval: TimeInterval = 1
  private static let memoryEagerSamples = 10
  private static let memoryLogInterval: TimeInterval = 10

  // The kernel's pressure source only fires on a transition, so a provider that
  // starts already tight would sit on the normal-pressure heartbeat until one
  // arrives. Treat scarce headroom as elevated too. A healthy tunnel plateaus
  // around 13 MB free of the 50 MB cap and the killed ones were under 10 MB, so
  // this trips only when genuinely close.
  private static let lowHeadroomBytes = 10 * 1024 * 1024

  // Every logger field is confined to this serial queue, and both dispatch
  // sources fire on it. cancel() does not interrupt a handler already running,
  // so teardown joins the queue rather than assuming sampling has stopped.
  private let memoryQueue = DispatchQueue(label: "org.getlantern.lantern.tunnel.memory")

  override func startTunnel(options: [String: NSObject]?) async throws {
    try await super.startTunnel(options: options)
    startMemoryLogger()
  }

  override func stopTunnel(with reason: NEProviderStopReason) async {
    // Record the reason and a final sample before any teardown work: an outright
    // kill never reaches this at all, so its absence is itself the signal.
    appLogger.info("PacketTunnelProvider stopping, reason: \(reason.rawValue)")
    memoryQueue.sync { _ = logMemoryUsage() }
    stopMemoryLogger()
    try? await super.stopTunnel(with: reason)
  }

  private func startMemoryLogger(interval: TimeInterval = PacketTunnelProvider.memorySampleInterval)
  {
    stopMemoryLogger()
    startMemoryPressureMonitor()
    let timer = DispatchSource.makeTimerSource(queue: memoryQueue)
    timer.schedule(deadline: .now(), repeating: interval)
    timer.setEventHandler { [weak self] in
      self?.sampleMemory()
    }
    memoryLogTimer = timer
    timer.resume()
  }

  private func stopMemoryLogger() {
    memoryLogTimer?.cancel()
    memoryLogTimer = nil
    memoryPressureSource?.cancel()
    memoryPressureSource = nil
    // A handler already in flight when cancel() lands still runs to completion;
    // draining the queue first keeps it from resetting state after this does, or
    // logging a sample once the tunnel is gone.
    memoryQueue.sync {
      currentMemoryPressure = .normal
      memorySampleCount = 0
      lastMemoryLog = nil
    }
  }

  // Logs every early sample so a fast pre-kill climb is visible, every sample
  // once memory is tight, and a 10s heartbeat otherwise. Runs on memoryQueue.
  private func sampleMemory() {
    let now = Date()
    memorySampleCount += 1
    let elevated = currentMemoryPressure != .normal
      || os_proc_available_memory() < Self.lowHeadroomBytes
    let heartbeatDue =
      lastMemoryLog.map { now.timeIntervalSince($0) >= Self.memoryLogInterval } ?? true
    guard memorySampleCount <= Self.memoryEagerSamples || elevated || heartbeatDue else { return }
    // Only a sample that actually read the counters may start the next heartbeat,
    // or a failed read would suppress logging for the following ten seconds.
    if logMemoryUsage() {
      lastMemoryLog = now
    }
  }

  // Subscribes to kernel memory-pressure notifications. The OS publishes one
  // of three levels (normal / warning / critical) — we mirror the latest into
  // currentMemoryPressure so each log line carries the system's own label.
  private func startMemoryPressureMonitor() {
    let source = DispatchSource.makeMemoryPressureSource(
      eventMask: [.normal, .warning, .critical],
      queue: memoryQueue
    )
    source.setEventHandler { [weak self, weak source] in
      guard let self = self, let source = source else { return }
      self.currentMemoryPressure = source.data
    }
    memoryPressureSource = source
    source.resume()
  }


  // Returns whether the counters were read, so a failed sample doesn't count as
  // a heartbeat. Runs on memoryQueue.
  @discardableResult
  private func logMemoryUsage() -> Bool {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard kerr == KERN_SUCCESS else {
      appLogger.error("PacketTunnelProvider failed to read memory info: \(kerr)")
      return false
    }
    let mb = 1024.0 * 1024.0
    let footprintMB = Double(info.phys_footprint) / mb
    let residentMB = Double(info.resident_size) / mb
    let peakMB = Double(info.resident_size_peak) / mb
    let virtualMB = Double(info.virtual_size) / mb
    let dirtyMB = Double(info.internal) / mb
    let compressedMB = Double(info.compressed) / mb
    // os_proc_available_memory: bytes remaining before iOS jetsams this process.
    // Returns 0 on platforms / processes without a limit (e.g. macOS host app).
    let availableBytes = os_proc_available_memory()
    let availableMB = Double(availableBytes) / mb
    let pressureLabel: String
    switch currentMemoryPressure {
    case .critical:
      pressureLabel = "critical"
    case .warning:
      pressureLabel = "warning"
    default:
      pressureLabel = "normal"
    }
    let message = String(
      format:
        "PacketTunnelProvider memory [pressure=%@] — footprint: %.2f MB, available: %.2f MB, resident: %.2f MB, peak: %.2f MB, dirty: %.2f MB, compressed: %.2f MB, virtual: %.2f MB",
      pressureLabel, footprintMB, availableMB, residentMB, peakMB, dirtyMB, compressedMB, virtualMB
    )
    appLogger.info("\(message)")
    return true
  }

  public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
  {
    appLogger.info("PacketTunnelProvider received app message with data: \(messageData)")
    func respond(_ dict: [String: Any]) {
      appLogger.info("PacketTunnelProvider responding with: \(dict)")
      let data = try? JSONSerialization.data(withJSONObject: dict)
      completionHandler?(data)
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
      let method = json["method"] as? String,
      let params = json["params"] as? [String: Any]
    else {
      appLogger.error("PacketTunnelProvider received invalid message format")
      return respond(["error": "Invalid message format"])
    }

    appLogger.info("PacketTunnelProvider handling method: \(method) with params: \(params)")

    switch method {
    case "PrivateServer":
      appLogger.info("Received connectServer command with params: \(params)")
      guard let server = params["server"] as? String else {
        return respond(["error": "Missing parameters"])
      }
      appLogger.info("VPN already active received connectServer command with params: \(params)")
      connectToServer(serverName: server) { success, errorMessage in
        if success {
          respond(["result": "Connected to \(server)"])
        } else {
          respond(["error": errorMessage ?? "Unknown error"])
        }
      }
      break
    case "Lantern":
      appLogger.info("VPN already active connecting to Lantern/auto")
      connectToServer(serverName: "auto") { success, errorMessage in
        if success {
          respond(["result": "Connected to auto tag"])
        } else {
          respond(["error": errorMessage ?? "Unknown error"])
        }
      }
      break
    default:
      respond(["error": "Unknown method"])
    }
  }
}
