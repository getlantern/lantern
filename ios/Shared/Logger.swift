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
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Lantern-IOS")
  private let logFileURL: URL

  init() {
    // Ensure Logs directory exists
    let logsDir = FilePath.logsDirectory
    if !FileManager.default.fileExists(atPath: logsDir.path) {
      try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    // Log file path
    self.logFileURL = logsDir.appendingPathComponent("lantern_ios.log")

    // Create empty file if missing
    if !FileManager.default.fileExists(atPath: logFileURL.path) {
      FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
  }

  private func writeToFile(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let formatted = "[\(timestamp)] \(message)\n"

    guard let data = formatted.data(using: .utf8) else { return }

    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
      fileHandle.seekToEndOfFile()
      fileHandle.write(data)
      try? fileHandle.close()
    }
  }

  func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
    writeToFile("[DEBUG] \(message)")
  }

  func info(_ message: String) {
    logger.info("\(message, privacy: .public)")
    writeToFile("[INFO] \(message)")
  }

  func error(_ message: String) {
    logger.error("\(message, privacy: .public)")
    writeToFile("[ERROR] \(message)")
  }

  func logFile() -> URL {
    return logFileURL
  }
}
