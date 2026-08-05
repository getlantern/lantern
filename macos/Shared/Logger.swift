//
//  Logger.swift
//  Runner
//
//  Created by jigar fumakiya on 20/07/23.
//

import Foundation
import os

let appLogger = LanternLogger()

class LanternLogger {
  private let queue = DispatchQueue(label: "LanternLoggerQueue", qos: .utility)
  private var fileHandle: FileHandle?
  private let logger = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "org.getlantern.lantern",
    category: "Lantern"
  )
  private let formatter = DateFormatter()
  private let utcTimeZone = TimeZone(identifier: "UTC")

  init() {
    let logFileURL = FilePath.logsDirectory.appendingPathComponent("lantern_macos.log")

    if !FileManager.default.fileExists(atPath: logFileURL.path) {
      FileManager.default.createFile(
        atPath: logFileURL.path, contents: nil, attributes: nil)
    }

    // Open for writing
    do {
      fileHandle = try FileHandle(forWritingTo: logFileURL)
      fileHandle?.seekToEndOfFile()  // move cursor to end
    } catch {
      print("Failed to open log file: \(error)")
    }
  }

  private func writeToFile(_ message: String, level: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let timestamp = formatTimestamp(Date())
      let formatted = "time=\"\(timestamp)\" level \(level) \(message)\n"
      guard let data = formatted.data(using: .utf8) else { return }
      self.fileHandle?.seekToEndOfFile()
      self.fileHandle?.write(data)
      self.fileHandle?.synchronizeFile()
    }
  }

  func log(_ message: String) {
    os_log("%{public}@", log: logger, type: .debug, String(describing: message))
    writeToFile(message, level: "DEBUG")
  }

  func info(_ message: String) {
    os_log("%{public}@", log: logger, type: .info, String(describing: message))
    writeToFile(message, level: "INFO")
  }

  func error(_ message: String) {
    os_log("%{public}@", log: logger, type: .error, String(describing: message))
    writeToFile(message, level: "ERROR")
  }

  /// Formats timestamp as: 2026-01-20 16:03:50.628 UTC
  private func formatTimestamp(_ date: Date) -> String {
    formatter.timeZone = utcTimeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return "\(formatter.string(from: date)) UTC"
  }

  deinit {
    try? fileHandle?.close()
  }
}
