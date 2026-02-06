//
//  PrivateServerListener.swift
//  Runner
//
//  Created by jigar fumakiya on 23/06/25.
//

import Foundation

/// Listens for private server events from the Go FFI layer.
/// Events are received via the Swift event callback registered with Go.
class PrivateServerListener: NSObject {

  static let shared = PrivateServerListener()
  @Published private(set) var eventSink: String = ""

  func openBrowser(_ url: String?) {
    let json: [String: String?] = ["status": "openBrowser", "data": url]
    if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: []),
      let jsonString = String(data: jsonData, encoding: .utf8)
    {
      eventSink = jsonString
    }
  }

  func onPrivateServerEvent(_ event: String?) {
    appLogger.log("Private server event received: \(event ?? "nil")")
    eventSink = event ?? ""
  }

  func onError(_ err: String?) {
    appLogger.error("Private server error: \(err ?? "nil")")
    eventSink = err ?? ""
  }

}
