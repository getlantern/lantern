//
//  VPNWidgetIntents.swift
//  Shared
//
//  App Intents behind the widget's button and the Control Center toggle.
//  Compiled into both Runner and LanternWidget so the same type exists in both
//  processes, but each process drives the tunnel its own way:
//
//  * LanternWidget (LANTERN_WIDGET_EXTENSION) talks to NETunnelProviderManager
//    directly via WidgetTunnelController, so a tap never has to open the app.
//  * Runner routes through VPNManager via `VPNIntentBridge.handler`, installed
//    in AppDelegate, so Shortcuts / Siri share the app's connection logic.
//

import AppIntents
import Foundation

public enum VPNIntentError: LocalizedError {
  case handlerUnavailable

  public var errorDescription: String? {
    switch self {
    case .handlerUnavailable:
      return "Lantern is not ready yet. Open the app and try again."
    }
  }
}

public enum VPNIntentBridge {
  /// Installed by the host app; unused inside the widget extension.
  public static var handler: ((VPNWidgetAction) async throws -> Void)?

  static func perform(_ action: VPNWidgetAction) async throws {
    #if LANTERN_WIDGET_EXTENSION
      try await WidgetTunnelController.perform(action)
    #else
      // Can fire before AppDelegate installs the handler; don't report success.
      guard let handler else {
        appLogger.error("VPN intent \(action.rawValue) fired before the app installed a handler")
        throw VPNIntentError.handlerUnavailable
      }
      try await handler(action)
    #endif
  }
}

@available(iOS 17.0, *)
public struct ToggleVPNIntent: AppIntent {
  public static let title: LocalizedStringResource = "Toggle Lantern VPN"
  public static let description = IntentDescription("Connects or disconnects Lantern VPN.")

  public init() {}

  public func perform() async throws -> some IntentResult {
    try await VPNIntentBridge.perform(.toggle)
    return .result()
  }
}

@available(iOS 18.0, *)
public struct SetVPNStateIntent: SetValueIntent {
  public static let title: LocalizedStringResource = "Set Lantern VPN"
  public static let description = IntentDescription("Turns Lantern VPN on or off.")

  @Parameter(title: "Connected")
  public var value: Bool

  public init() {}

  public init(value: Bool) {
    self.value = value
  }

  public func perform() async throws -> some IntentResult {
    try await VPNIntentBridge.perform(value ? .connect : .disconnect)
    return .result()
  }
}
