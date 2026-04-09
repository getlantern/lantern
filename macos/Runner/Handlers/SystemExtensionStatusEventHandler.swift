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

    // Drop the first (unverified) value — the @Published property starts at
    // .notInstalled before the init-time properties query completes. Without
    // this, Flutter briefly sees .notInstalled and may show the installation
    // dialog even when the extension is already installed.
    cancellable = SystemExtensionManager.shared.$status
      .dropFirst()
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
