//
//  WidgetPalette.swift
//  LanternWidget
//
//  Colors resolved from VPN state. Hex values are copied from
//  lib/core/common/app_colors.dart so the widget matches the app exactly and
//  never depends on asset-catalog lookups at render time.
//

import SwiftUI

extension Color {
  init(hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255,
      opacity: 1)
  }
}

/// Raw palette (AppColors.*).
enum LanternColor {
  static let white = Color(hex: 0xFFFFFF)
  static let blue4 = Color(hex: 0x00BDD6)
  static let gray3 = Color(hex: 0xDEDFDF)
  static let gray5 = Color(hex: 0xA2A2A2)
  static let gray8 = Color(hex: 0x3E464E)
  static let green6 = Color(hex: 0x0A8638)
  static let green12 = Color(hex: 0x1FBF63)
  static let yellow3 = Color(hex: 0xFFC105)
  /// Widget card surface from the design; dark in both appearances.
  static let card = Color(hex: 0x1F2B2B)
}

/// Semantic colors for one render of the home screen widget. The card is
/// always dark, so the palette does not depend on the color scheme.
struct WidgetPalette {
  let status: VPNWidgetStatus

  /// The switch reads "on" for every state where the tunnel is (still) up,
  /// so it flips exactly once per toggle instead of mid-transition.
  var isOn: Bool { status != .disconnected }

  var background: Color { LanternColor.card }
  var accent: Color { LanternColor.blue4 }
  /// Switch track when on / off.
  var switchOn: Color { LanternColor.green6 }
  var switchOff: Color { LanternColor.gray8 }
  var textPrimary: Color { LanternColor.white }
  var textSecondary: Color { LanternColor.gray3 }

  var statusDot: Color {
    switch status {
    case .connected: return LanternColor.green12
    case .connecting, .disconnecting: return LanternColor.yellow3
    case .disconnected: return LanternColor.gray5
    }
  }
}
