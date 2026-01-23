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
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Lantern")
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
      try fileHandle?.seekToEnd()  // move cursor to end
    } catch {
      print("Failed to open log file: \(error)")
    }
  }

  private func writeToFile(_ message: String, level: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let timestamp = formatTimestamp(Date.now)
      let formatted = "time=\"\(timestamp)\" level \(level) \(message)\n"
      guard let data = formatted.data(using: .utf8) else { return }
      do {
        _ = try self.fileHandle?.seekToEnd()
        self.fileHandle?.write(data)
        self.fileHandle?.synchronizeFile()
      } catch {
        print("Log write error: \(error)")
      }
    }
  }

  func log(_ message: String) {
    logger.debug("\(String(describing: message), privacy: .public)")
    writeToFile(message, level: "DEBUG")
  }

  func info(_ message: String) {
    logger.info("\(String(describing: message), privacy: .public)")
    writeToFile(message, level: "INFO")
  }

  func error(_ message: String) {
    logger.error("\(String(describing: message), privacy: .public)")
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
