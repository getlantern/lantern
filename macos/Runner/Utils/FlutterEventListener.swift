//
//  FlutterEventListener.swift
//  Runner
//
//  Created by jigar fumakiya on 06/10/25.
//

import FlutterMacOS
import Foundation

/// Simple event structure for FFI events
struct FlutterEvent {
  let type: String
  let message: String
}

/// Listens for events from the Go FFI layer and forwards them to Flutter.
class FlutterEventListener: NSObject {
  static let shared = FlutterEventListener()

  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any?]] = []
  private let lock = NSLock()

  func send(type: String, message: String) {
    appLogger.log("FlutterEventListener sending event: \(type) - \(message)")
    let map: [String: Any] = [
      "type": type,
      "message": message,
    ]

    lock.lock()
    if let sink = eventSink {
      lock.unlock()
      appLogger.log("FlutterEventListener sending event immediately: \(map)")
      DispatchQueue.main.async {
        sink(map)
      }
    } else {
      // Buffer it
      appLogger.log("FlutterEventListener buffering event: \(map)")
      pendingEvents.append(map)
      lock.unlock()
    }
  }

  func attachSink(_ sink: @escaping FlutterEventSink) {
    eventSink = sink

    // Drain any pending events when Flutter starts listening
    lock.lock()
    let eventsToSend = pendingEvents
    pendingEvents.removeAll()
    lock.unlock()

    for event in eventsToSend {
      sink(event)
    }
  }

  func detachSink() {
    eventSink = nil
  }

}
