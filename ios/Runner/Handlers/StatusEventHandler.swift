//  Based on ConnectionStatusHandler.swift
// 
//  Based on StatusEventHandler.swift
//  Created by GFWFighter on 10/24/23.
//

import Foundation
import Combine

public class StatusEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
    static let name = "org.getlantern.lantern/status"
    
    private var channel: FlutterEventChannel?
    
    private var cancellable: AnyCancellable?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = StatusEventHandler()
        instance.channel = FlutterEventChannel(name: Self.name, binaryMessenger: registrar.messenger(), codec: FlutterJSONMethodCodec())
        instance.channel?.setStreamHandler(instance)
    }
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        cancellable = VPNManager.shared.$connectionStatus.sink { [events] status in
            switch status {
            case .reasserting, .connecting:
                events(["status": "Connecting"])
            case .connected:
                events(["status": "Connected"])
            case .disconnecting:
                events(["status": "Disconnecting"])
            case .disconnected, .invalid:
                events(["status": "Disconnected"])
            @unknown default:
                events(["status": "Disconnected"])
            }
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        cancellable?.cancel()
        return nil
    }
}
