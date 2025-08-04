//
//  TunnelLogger.swift
//  Runner
//
//  Created by jigar fumakiya on 04/08/25.
//

import os.log

let tunnelLogger = TunnelLogger()

class TunnelLogger {
    private let systemIdentifier = org.getlantern.lantern.PacketTunnel"
  private let generalLog = OSLog(
    subsystem: systemIdentifier, category: "General")
  private let networkLog = OSLog(
    subsystem: systemIdentifier, category: "Networking")
  private let debugLog = OSLog(subsystem: systemIdentifier, category: "Debug")

  func log(_ message: String) {
    os_log("%{public}@", log: generalLog, type: .default, message)
  }

  func info(_ message: String) {
    os_log("INFO: %{public}@", log: generalLog, type: .info, message)
  }

  func debug(_ message: String) {
    os_log("DEBUG: %{public}@", log: debugLog, type: .debug, message)
  }

  func error(_ message: String) {
    os_log("ERROR: %{public}@", log: generalLog, type: .error, message)
  }

  func network(_ message: String) {
    os_log("NET: %{public}@", log: networkLog, type: .default, message)
  }
}
