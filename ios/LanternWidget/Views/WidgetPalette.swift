//
//  WidgetPalette.swift
//  LanternWidget
//
//  Colors resolved from VPN state and appearance. Hex values are copied from
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
  static let blue1 = Color(hex: 0xF0FDFF)
  static let blue2 = Color(hex: 0xD6F6FA)
  static let blue3 = Color(hex: 0x6AD8E7)
  static let blue4 = Color(hex: 0x00BDD6)
  static let blue5 = Color(hex: 0x009EB2)
  static let blue6 = Color(hex: 0x008394)
  static let blue7 = Color(hex: 0x005F61)
  static let blue8 = Color(hex: 0x004D57)
  static let blue9 = Color(hex: 0x00353D)
  static let blue10 = Color(hex: 0x012D2D)
  static let gray1 = Color(hex: 0xF8FAFB)
  static let gray2 = Color(hex: 0xEDEFEF)
  static let gray3 = Color(hex: 0xDEDFDF)
  static let gray4 = Color(hex: 0xBFBFBF)
  static let gray5 = Color(hex: 0xA2A2A2)
  static let gray7 = Color(hex: 0x616569)
  static let gray8 = Color(hex: 0x3E464E)
  static let gray850 = Color(hex: 0x2D3136)
  static let gray9 = Color(hex: 0x1B1C1D)
  static let green3 = Color(hex: 0xA2DDAF)
  static let green6 = Color(hex: 0x0A8638)
  static let green12 = Color(hex: 0x1FBF63)
  static let yellow3 = Color(hex: 0xFFC105)
  static let yellow4 = Color(hex: 0xD6A100)
}

/// Semantic colors for one render of the widget.
struct WidgetPalette {
  let status: VPNWidgetStatus
  let colorScheme: ColorScheme

  private var isDark: Bool { colorScheme == .dark }
  /// The teal "on" look covers every state where the tunnel is (still) up,
  /// including disconnecting. The background therefore changes exactly once
  /// per toggle, at the terminal state, instead of flashing white mid-way.
  var isOn: Bool { status != .disconnected }

  /// Brand accent: action.toggle.toggle-brand-active-bg (Blue.400 / Blue.600),
  /// the color the app's VPN switch turns when the tunnel is on.
  var accent: Color { isDark ? LanternColor.blue6 : LanternColor.blue4 }
  /// Accent for glyphs on a surface, lifted for contrast on dark backgrounds.
  var accentForeground: Color {
    if isOn { return LanternColor.blue2 }
    return isDark ? LanternColor.blue3 : LanternColor.blue5
  }
  /// Bright accent used for rings and glows over the teal "on" background.
  var accentHighlight: Color { isDark ? LanternColor.blue3 : LanternColor.blue4 }

  // Background gradient stops.
  var backgroundTop: Color {
    if isOn { return isDark ? LanternColor.blue7 : LanternColor.blue5 }
    return isDark ? LanternColor.gray850 : LanternColor.white
  }
  var backgroundBottom: Color {
    if isOn { return isDark ? LanternColor.blue9 : LanternColor.blue7 }
    return isDark ? LanternColor.gray9 : LanternColor.gray2
  }
  /// Accent glow behind the content; strong when on, a hint when off.
  var glow: Color {
    isOn ? LanternColor.blue4.opacity(isDark ? 0.35 : 0.45) : accent.opacity(isDark ? 0.18 : 0.14)
  }
  /// Faint accent-tinted shield in the corner.
  var ornament: Color {
    isOn ? LanternColor.blue3.opacity(0.18) : accent.opacity(isDark ? 0.14 : 0.10)
  }

  var textPrimary: Color {
    if isOn { return LanternColor.white }
    return isDark ? LanternColor.gray2 : LanternColor.gray9
  }
  var textSecondary: Color {
    if isOn { return LanternColor.blue2.opacity(0.9) }
    return isDark ? LanternColor.gray4 : LanternColor.gray7
  }

  var statusDot: Color {
    switch status {
    case .connected: return isDark ? LanternColor.green3 : LanternColor.green12
    case .connecting, .disconnecting: return isDark ? LanternColor.yellow3 : LanternColor.yellow4
    case .disconnected: return isDark ? LanternColor.gray5 : LanternColor.gray4
    }
  }

  // Primary action button. Off: solid brand accent (the switch's "on"
  // color, inviting the tap). On: translucent with an accent ring.
  var buttonFill: Color {
    if isOn { return LanternColor.white.opacity(isDark ? 0.12 : 0.16) }
    return accent
  }
  var buttonStroke: Color {
    isOn ? accentHighlight.opacity(0.9) : .clear
  }
  var buttonText: Color {
    if isOn { return LanternColor.white }
    return isDark ? LanternColor.gray1 : LanternColor.blue10
  }
}
