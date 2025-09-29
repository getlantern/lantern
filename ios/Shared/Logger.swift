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
    logger.debug("\(String(describing: message), privacy: .public)")
  }

  func info(_ message: String) {
    logger.info("\(String(describing: message), privacy: .public)")
  }

  func error(_ message: String) {
    logger.error("\(String(describing: message), privacy: .public)")
  }
}
