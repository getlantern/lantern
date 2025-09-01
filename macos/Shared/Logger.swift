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
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Lantern")

  func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
  }

  // if you want to see logs in console use info
  func info(_ message: String) {
    logger.info("\(message, privacy: .public)")
  }

  func error(_ message: String) {
    logger.error("\(message, privacy: .public)")
  }
}
