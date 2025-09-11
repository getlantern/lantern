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

  init() {
    fileHandle = try? FileHandle(forWritingTo: FilePath.macOSLogDirectory)
    fileHandle?.seekToEndOfFile()
  }

  private func writeToFile(_ message: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      guard let data = (message + "\n").data(using: .utf8) else { return }
      do {
        try self.fileHandle?.seekToEnd()
        self.fileHandle?.write(data)
      } catch {
        print("Log write error: \(error)")
      }
    }
  }

  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Lantern")

  func log(_ message: String) {
    logger.debug("\(String(describing: message), privacy: .public)")
    writeToFile("[DEBUG] \(message)")
  }

  func info(_ message: String) {
    logger.info("\(String(describing: message), privacy: .public)")
    writeToFile("[INFO] \(message)")

  }

  func error(_ message: String) {
    logger.error("\(String(describing: message), privacy: .public)")
    writeToFile("[ERROR] \(message)")
  }

  deinit {
    try? fileHandle?.close()
  }
}
