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

  /// Frequent event diagnostics use opt-in trace logging.
  private static let highVolumeEvents: Set<String> = [
    "peer-connection",
    "data-cap-event",
  ]

  func send(_ event: UtilsFlutterEvent?) {
    guard let event = event else { return }

    func logEvent(_ message: @autoclosure () -> String) {
      if Self.highVolumeEvents.contains(event.type) {
        appLogger.trace(message())
      } else {
        appLogger.log(message())
      }
    }
    logEvent("FlutterEventListener sending event: \(event.type) - \(event.message)")
    let map: [String: Any] = [
      "type": event.type,
      "message": event.message,
    ]

    lock.lock()
    if let sink = eventSink {
      lock.unlock()
      logEvent("FlutterEventListener sending event immediately: \(map)")
      DispatchQueue.main.async {
        sink(map)
      }
    } else {
      logEvent("FlutterEventListener buffering event: \(event.type)")
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
