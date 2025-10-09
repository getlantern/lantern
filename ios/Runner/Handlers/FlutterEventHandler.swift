//
//  FlutterEventHandler.swift
//  Runner
//
//  Created by jigar fumakiya on 06/10/25.
//

import Combine

class FlutterEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/app_events"
  private var channel: FlutterEventChannel?
  private var cancellable: AnyCancellable?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FlutterEventHandler()
    instance.channel = FlutterEventChannel(
      name: self.name, binaryMessenger: registrar.messenger(), codec: FlutterJSONMethodCodec())
    instance.channel?.setStreamHandler(instance)
    appLogger.info("FlutterEventHandler registered")
  }

  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    FlutterEventListener.shared.attachSink(eventSink)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    FlutterEventListener.shared.detachSink()
    return nil
  }

}
