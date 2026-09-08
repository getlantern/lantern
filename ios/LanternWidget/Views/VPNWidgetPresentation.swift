//
//  VPNWidgetPresentation.swift
//  LanternWidget
//
//  Display strings and symbols for a VPNWidgetState, shared by every family.
//

import SwiftUI

struct VPNWidgetPresentation {
  let state: VPNWidgetState

  var title: LocalizedStringKey {
    switch state.status {
    case .connected: return "Connected"
    case .connecting: return "Connecting…"
    case .disconnecting: return "Disconnecting…"
    case .disconnected: return "Not connected"
    }
  }

  var shortTitle: LocalizedStringKey {
    switch state.status {
    case .connected: return "On"
    case .connecting, .disconnecting: return "…"
    case .disconnected: return "Off"
    }
  }

  /// Where the tunnel exits. The app pushes the resolved city/country once it
  /// knows it; until then fall back to the chosen server tag.
  var locationText: String {
    if !state.locationName.isEmpty { return state.locationName }
    if state.isAutoServer { return String(localized: "Best location") }
    return state.serverName
  }

  var flag: String? { state.flagEmoji }

  /// Secondary line under the status.
  var subtitle: LocalizedStringKey {
    switch state.status {
    case .connected, .connecting, .disconnecting:
      return LocalizedStringKey(locationText)
    case .disconnected:
      return state.isAutoServer ? "Protect your connection" : LocalizedStringKey(locationText)
    }
  }

  /// Button label. While a transition runs the button is disabled and shows
  /// what is happening rather than an action that cannot be taken yet.
  var actionTitle: LocalizedStringKey {
    switch state.status {
    case .connected: return "Disconnect"
    case .disconnected: return "Connect"
    case .connecting: return "Connecting…"
    case .disconnecting: return "Disconnecting…"
    }
  }

  var symbolName: String {
    switch state.status {
    case .connected: return "checkmark.shield.fill"
    case .connecting, .disconnecting: return "shield.lefthalf.filled"
    case .disconnected: return "shield.slash"
    }
  }

  var accessibilityLabel: Text {
    Text("Lantern VPN, ") + Text(title) + Text(", ") + Text(locationText)
  }
}
