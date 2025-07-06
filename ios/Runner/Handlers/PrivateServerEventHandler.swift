//
//  PrivateServerEvent.swift
//  Runner
//
//  Created by jigar fumakiya on 23/06/25.
//

import Combine

class PrivateServerEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/private_server_status"
  private var channel: FlutterEventChannel?
  private var cancellable: AnyCancellable?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PrivateServerEventHandler()
    instance.channel = FlutterEventChannel(
      name: Self.name, binaryMessenger: registrar.messenger(), codec: FlutterJSONMethodCodec())
    instance.channel?.setStreamHandler(instance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    appLogger.info("PrivateServerEvent onListen called")
    cancellable = PrivateServerListener.shared.$eventSink
      .compactMap { $0 }
      .sink { event in
        appLogger.info("PrivateServerEvent received event: \(event)")
        if !event.isEmpty {
          events(event)
        }

      }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancellable?.cancel()
    cancellable = nil
    return nil
  }

}
