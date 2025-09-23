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

  /// Date formatter for timestamps
  private lazy var dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter
  }()

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

  private func timestamp() -> String {
    return dateFormatter.string(from: Date())
  }

  private func writeToFile(_ message: String, level: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let logLine = "[\(self.timestamp())] [\(level)] \(message)\n"
      guard let data = logLine.data(using: .utf8) else { return }
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

  deinit {
    try? fileHandle?.close()
  }
}
