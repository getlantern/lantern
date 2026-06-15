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

  /// Frequent event diagnostics use opt-in trace logging. The snapshots arrive
  /// every second while sharing and carry the addresses of the peers relayed.
  private static let highVolumeEvents: Set<String> = [
    "peer-connection",
    "data-cap-event",
    "unbounded-snapshot",
    "peer-snapshot",
    "user-message-available",
  ]

  // Go passes the event fields by value; a *FlutterEvent proxy could be
  // collected mid-call and abort the process with "Unknown reference".
  func sendEvent(_ eventType: String?, message: String?) {
    guard let eventType = eventType else { return }
    let message = message ?? ""

    func logEvent(_ text: @autoclosure () -> String) {
      if Self.highVolumeEvents.contains(eventType) {
        appLogger.trace(text())
      } else {
        appLogger.log(text())
      }
    }
    logEvent(
      "FlutterEventListener sending event: \(loggableFlutterEvent(type: eventType, message: message))"
    )
    let map: [String: Any] = [
      "type": eventType,
      "message": message,
    ]

    lock.lock()
    if let sink = eventSink {
      lock.unlock()
      DispatchQueue.main.async {
        sink(map)
      }
    } else {
      logEvent("FlutterEventListener buffering event: \(eventType)")
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
