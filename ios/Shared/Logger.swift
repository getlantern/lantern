//
//  Logger.swift
//  Runner
//
//  Created by jigar fumakiya on 20/07/23.
//

import os
import Foundation

let appLogger = LanternLogger()

class LanternLogger {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Swidr")
   
    func log(_ message: String) {
        logger.debug("\(message)")  
    }

    func info(_ message: String) {
        logger.info("\(message)")
    }

    func error(_ message: String) {
        logger.error("\(message)")
    }
}
