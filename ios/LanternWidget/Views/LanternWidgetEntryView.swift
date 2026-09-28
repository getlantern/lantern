//
//  LanternWidgetEntryView.swift
//  LanternWidget
//
//  Family-specific layouts. No fixed sizes beyond the logo, so layouts hold up
//  under large Dynamic Type, iPad grid sizes and StandBy. System content
//  margins are kept (no contentMarginsDisabled).
//

import AppIntents
import SwiftUI
import WidgetKit

struct LanternWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family

  let entry: VPNWidgetEntry

  private var presentation: VPNWidgetPresentation { VPNWidgetPresentation(state: entry.state) }
  private var palette: WidgetPalette { WidgetPalette(status: entry.state.status) }

  var body: some View {
    Group {
      switch family {
      case .systemSmall:
        HomeLayout(presentation: presentation, palette: palette, compact: true)
      case .systemMedium:
        HomeLayout(presentation: presentation, palette: palette, compact: false)
      case .accessoryCircular:
        CircularLayout(presentation: presentation)
      case .accessoryRectangular:
        RectangularLayout(presentation: presentation)
      case .accessoryInline:
        InlineLayout(presentation: presentation)
      default:
        HomeLayout(presentation: presentation, palette: palette, compact: true)
      }
    }
    .containerBackground(for: .widget) {
      if family.isAccessory {
        Color.clear
      } else {
        WidgetBackgroundView(palette: palette)
      }
    }
    // With no VPN profile the intents cannot work, so the whole widget opens
    // the app instead. Nil otherwise: a tap outside the switch does nothing.
    .widgetURL(entry.state.needsSetup ? URL(string: "lantern://") : nil)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(presentation.accessibilityLabel)
  }
}

extension WidgetFamily {
  var isAccessory: Bool {
    switch self {
    case .accessoryCircular, .accessoryRectangular, .accessoryInline: return true
    default: return false
    }
  }
}

// MARK: - Home screen

/// Small and medium share one layout: switch and logo on top, status in the
/// middle, flag and location at the bottom. `compact` picks the small
/// family's type sizes and city-only location.
private struct HomeLayout: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette
  let compact: Bool

  private var busy: Bool { presentation.state.status.isTransitioning }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center) {
        VPNSwitch(presentation: presentation, palette: palette, compact: compact)
        Spacer(minLength: 8)
        Image("LanternLogo")
          .resizable()
          .scaledToFit()
          .frame(width: compact ? 40 : 44, height: compact ? 40 : 44)
          .accessibilityHidden(true)
      }

      Spacer(minLength: 8)

      HStack(spacing: compact ? 8 : 10) {
        Circle()
          .fill(palette.statusDot)
          .frame(width: compact ? 14 : 18, height: compact ? 14 : 18)
          .widgetAccentable()
        Text(presentation.title)
          .font(compact ? .subheadline.weight(.medium) : .title2.weight(.medium))
          .foregroundStyle(palette.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .invalidatableContent()
      }

      Spacer(minLength: 6)

      HStack(spacing: compact ? 8 : 10) {
        if presentation.state.needsSetup {
          Image(systemName: "arrow.up.forward.app")
            .font((compact ? Font.subheadline : .body).weight(.semibold))
            .foregroundStyle(palette.accent)
          Text(presentation.setupHint)
            .font(compact ? .subheadline : .body)
            .foregroundStyle(palette.textSecondary)
            .lineLimit(compact ? 2 : 1)
            .minimumScaleFactor(0.75)
        } else {
          if let flag = presentation.flag {
            Text(flag)
              .font(compact ? .title3 : .title2)
          } else {
            Image(systemName: "globe")
              .font((compact ? Font.subheadline : .body).weight(.semibold))
              .foregroundStyle(palette.textSecondary)
          }
          Text(compact ? presentation.shortLocation : presentation.longLocation)
            .font(compact ? .subheadline : .body)
            .foregroundStyle(palette.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
      }
    }
  }
}

/// The connect switch, drawn as a track and knob so it reads as a tappable
/// switch. WidgetKit's own `Toggle` renders as a flat pill in widgets, and
/// `.toggleStyle(.switch)` is UIKit-backed and gets dropped entirely.
private struct VPNSwitch: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette
  let compact: Bool

  private var busy: Bool { presentation.state.status.isTransitioning }
  private var height: CGFloat { compact ? 32 : 36 }
  private var width: CGFloat { height * 1.9 }
  private var knob: CGFloat { height - 6 }

  var body: some View {
    if presentation.state.needsSetup {
      // Not a button: the intent would only fail again. widgetURL opens the app.
      track
    } else {
      Button(intent: ToggleVPNIntent()) {
        track
      }
      .buttonStyle(.plain)
      .disabled(busy)
      .invalidatableContent()
      .accessibilityLabel(Text("Lantern VPN"))
      .accessibilityValue(Text(presentation.title))
      .accessibilityAddTraits(.isToggle)
    }
  }

  private var track: some View {
    ZStack(alignment: palette.isOn ? .trailing : .leading) {
      Capsule()
        .fill(palette.isOn ? palette.switchOn : palette.switchOff)
      Circle()
        .fill(palette.textPrimary)
        .frame(width: knob, height: knob)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        .padding(3)
    }
    .frame(width: width, height: height)
    .contentShape(Capsule())
  }
}

// MARK: - Lock screen (system-tinted, no custom colors)

private struct CircularLayout: View {
  let presentation: VPNWidgetPresentation

  var body: some View {
    Button(intent: ToggleVPNIntent()) {
      ZStack {
        AccessoryWidgetBackground()
        VStack(spacing: 1) {
          Image(systemName: presentation.symbolName)
            .font(.title3)
          Text(presentation.shortTitle)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding(4)
      }
    }
    .buttonStyle(.plain)
    .disabled(presentation.state.status.isTransitioning || presentation.state.needsSetup)
    .invalidatableContent()
  }
}

private struct RectangularLayout: View {
  let presentation: VPNWidgetPresentation

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        HStack(spacing: 4) {
          Image(systemName: presentation.symbolName)
          Text("Lantern VPN")
        }
        .font(.headline)
        .lineLimit(1)
        Text(presentation.title)
          .font(.caption)
          .lineLimit(1)
          .invalidatableContent()
        HStack(spacing: 3) {
          if let flag = presentation.flag, presentation.state.status != .disconnected {
            Text(flag)
          }
          if presentation.state.needsSetup {
            Text(presentation.setupHint)
          } else {
            Text(presentation.locationText)
          }
        }
        .font(.caption2)
        .lineLimit(1)
        .opacity(0.8)
      }
      .minimumScaleFactor(0.7)
      Spacer(minLength: 0)
      Button(intent: ToggleVPNIntent()) {
        Image(
          systemName: presentation.state.status != .disconnected
            ? "power.circle.fill" : "power.circle")
          .font(.title2)
      }
      .buttonStyle(.plain)
      .disabled(presentation.state.status.isTransitioning || presentation.state.needsSetup)
      .invalidatableContent()
    }
  }
}

private struct InlineLayout: View {
  let presentation: VPNWidgetPresentation

  var body: some View {
    ViewThatFits {
      Label {
        Text("Lantern: ") + Text(presentation.title)
      } icon: {
        Image(systemName: presentation.symbolName)
      }
      Label {
        Text(presentation.shortTitle)
      } icon: {
        Image(systemName: presentation.symbolName)
      }
    }
  }
}
