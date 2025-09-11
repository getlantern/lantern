//
//  SystemExtensionStatusHandler.swift
//  Runner
//
//  Created by jigar fumakiya on 10/09/25.
//
import Combine
import FlutterMacOS
import Foundation

public class SystemExtnesionStatusEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/system_extension_status"
  private var channel: FlutterEventChannel?
  private var cancellable: AnyCancellable?
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SystemExtnesionStatusEventHandler()
    instance.channel = FlutterEventChannel(
      name: Self.name, binaryMessenger: registrar.messenger, codec: FlutterJSONMethodCodec())
    instance.channel?.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    cancellable =  SystemExtensionManager.shared.$status
          .sink { status in
              events(["status": status])
          }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancellable?.cancel()
    return nil
  }
}
