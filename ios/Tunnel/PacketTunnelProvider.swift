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

  override func startTunnel(options: [String: NSObject]?) async throws {
    try await super.startTunnel(options: options)
    startMemoryLogger()
  }

  override func stopTunnel(with reason: NEProviderStopReason) async {
    // Record the reason and a final sample before any teardown work: an outright
    // kill never reaches this at all, so its absence is itself the signal.
    appLogger.info("PacketTunnelProvider stopping, reason: \(reason.rawValue)")
    logMemoryUsage()
    stopMemoryLogger()
    try? await super.stopTunnel(with: reason)
  }

  private func startMemoryLogger(interval: TimeInterval = PacketTunnelProvider.memorySampleInterval)
  {
    stopMemoryLogger()
    startMemoryPressureMonitor()
    let timer = DispatchSource.makeTimerSource(queue: .global(qos: .utility))
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
    currentMemoryPressure = .normal
    memorySampleCount = 0
    lastMemoryLog = nil
  }

  // Logs every early sample so a fast pre-kill climb is visible, every sample
  // once the kernel reports pressure, and a 10s heartbeat otherwise.
  private func sampleMemory() {
    memorySampleCount += 1
    let elevated = currentMemoryPressure != .normal
    let heartbeatDue =
      lastMemoryLog.map { Date().timeIntervalSince($0) >= Self.memoryLogInterval } ?? true
    guard memorySampleCount <= Self.memoryEagerSamples || elevated || heartbeatDue else { return }
    lastMemoryLog = Date()
    logMemoryUsage()
  }

  // Subscribes to kernel memory-pressure notifications. The OS publishes one
  // of three levels (normal / warning / critical) — we mirror the latest into
  // currentMemoryPressure so each log line carries the system's own label.
  private func startMemoryPressureMonitor() {
    let source = DispatchSource.makeMemoryPressureSource(
      eventMask: [.normal, .warning, .critical],
      queue: .global(qos: .utility)
    )
    source.setEventHandler { [weak self, weak source] in
      guard let self = self, let source = source else { return }
      self.currentMemoryPressure = source.data
    }
    memoryPressureSource = source
    source.resume()
  }


  private func logMemoryUsage() {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let kerr = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard kerr == KERN_SUCCESS else {
      appLogger.error("PacketTunnelProvider failed to read memory info: \(kerr)")
      return
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
