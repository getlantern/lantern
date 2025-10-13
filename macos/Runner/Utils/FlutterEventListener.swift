import FlutterMacOS
//
//  FlutterEventListener.swift
//  Runner
//
//  Created by jigar fumakiya on 06/10/25.
//
import Liblantern

class FlutterEventListener: NSObject, UtilsFlutterEventEmitterProtocol {
  static let shared = FlutterEventListener()

  private var eventSink: FlutterEventSink?
  private var pendingEvents: [[String: Any?]] = []
  private let lock = NSLock()

  func send(_ event: UtilsFlutterEvent?) {
    guard let event = event else { return }

    appLogger.log("FlutterEventListener sending event: \(event.type) - \(event.message)")
    let map: [String: Any] = [
      "type": event.type,
      "message": event.message,
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
