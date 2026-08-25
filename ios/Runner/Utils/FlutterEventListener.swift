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

  /// Event types that arrive continuously rather than occasionally: one per
  /// peer connection, and a data-cap poll every few seconds. Each event was
  /// logged up to twice with its full payload, which made them the bulk of a
  /// 277 MB log — and an oversized log is what pushes an issue report past its
  /// attachment budget, so the user cannot send us logs at all. They are still
  /// delivered; they are just no longer each worth two lines and a payload.
  private static let highVolumeEvents: Set<String> = [
    "peer-connection",
    "data-cap-event",
  ]

  func send(_ event: UtilsFlutterEvent?) {
    guard let event = event else { return }

    let logVerbosely = !Self.highVolumeEvents.contains(event.type)
    if logVerbosely {
      appLogger.log("FlutterEventListener sending event: \(event.type) - \(event.message)")
    }
    let map: [String: Any] = [
      "type": event.type,
      "message": event.message,
    ]

    lock.lock()
    if let sink = eventSink {
      lock.unlock()
      if logVerbosely {
        appLogger.log("FlutterEventListener sending event immediately: \(map)")
      }
      DispatchQueue.main.async {
        sink(map)
      }
    } else {
      // Buffer it. Always logged: buffering means Flutter is not listening
      // yet, which is rare and worth seeing even for a high-volume type.
      appLogger.log("FlutterEventListener buffering event: \(event.type)")
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
