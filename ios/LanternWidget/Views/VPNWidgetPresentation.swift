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
    case .disconnected: return "Not Connected"
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

  /// Compact location for the small family: the city alone when known.
  var shortLocation: String {
    if !state.city.isEmpty { return state.city }
    if !state.country.isEmpty { return state.country }
    return locationText
  }

  /// Full location for the medium family: "Country - City" when both are known.
  var longLocation: String {
    switch (state.country.isEmpty, state.city.isEmpty) {
    case (false, false): return "\(state.country) - \(state.city)"
    case (false, true): return state.country
    case (true, false): return state.city
    case (true, true): return locationText
    }
  }

  var flag: String? { state.flagEmoji }

  /// Shown in place of the location until the app has created the VPN profile.
  var setupHint: LocalizedStringKey { "Open Lantern to finish setup" }

  var symbolName: String {
    switch state.status {
    case .connected: return "checkmark.shield.fill"
    case .connecting, .disconnecting: return "shield.lefthalf.filled"
    case .disconnected: return "shield.slash"
    }
  }

  var accessibilityLabel: Text {
    if state.needsSetup { return Text("Lantern VPN, ") + Text(setupHint) }
    return Text("Lantern VPN, ") + Text(title) + Text(", ") + Text(locationText)
  }
}
