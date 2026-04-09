//
//  SystemExtensionStatusHandler.swift
//  Runner
//
//  Created by jigar fumakiya on 10/09/25.
//
import Combine
import FlutterMacOS
import Foundation

public class SystemExtensionStatusEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/system_extension_status"
  private var channel: FlutterEventChannel?
  private var cancellable: AnyCancellable?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = SystemExtensionStatusEventHandler()
    instance.channel = FlutterEventChannel(
      name: self.name, binaryMessenger: registrar.messenger, codec: FlutterJSONMethodCodec())
    instance.channel?.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {

    // Skip the placeholder .notInstalled emitted before the init-time
    // properties query completes. Once initialized, deliver every update.
    cancellable = SystemExtensionManager.shared.$status
      .filter { _ in SystemExtensionManager.shared.initialized }
      .sink { sysStatus in
        appLogger.info(
          "SystemExtensionStatusEvent received status: \(sysStatus.logDescription)")
        var payload: [String: Any] = ["status": sysStatus.code]
        if let details = sysStatus.details {
          payload["details"] = details
        }
        events(payload)
      }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    cancellable?.cancel()
    return nil
  }
}
