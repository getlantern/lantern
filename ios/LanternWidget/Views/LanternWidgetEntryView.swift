//
//  LanternWidgetEntryView.swift
//  LanternWidget
//
//  Family-specific layouts. No fixed sizes beyond the primary button's minimum
//  height, so layouts hold up under large Dynamic Type, iPad grid sizes and
//  StandBy. System content margins are kept (no contentMarginsDisabled) so the
//  button can never run past the widget's edge.
//

import AppIntents
import SwiftUI
import WidgetKit

struct LanternWidgetEntryView: View {
  @Environment(\.widgetFamily) private var family
  @Environment(\.colorScheme) private var colorScheme

  let entry: VPNWidgetEntry

  private var presentation: VPNWidgetPresentation { VPNWidgetPresentation(state: entry.state) }
  private var palette: WidgetPalette {
    WidgetPalette(status: entry.state.status, colorScheme: colorScheme)
  }

  var body: some View {
    Group {
      switch family {
      case .systemSmall:
        SmallLayout(presentation: presentation, palette: palette)
      case .systemMedium:
        MediumLayout(presentation: presentation, palette: palette)
      case .accessoryCircular:
        CircularLayout(presentation: presentation)
      case .accessoryRectangular:
        RectangularLayout(presentation: presentation)
      case .accessoryInline:
        InlineLayout(presentation: presentation)
      default:
        SmallLayout(presentation: presentation, palette: palette)
      }
    }
    .containerBackground(for: .widget) {
      if family.isAccessory {
        Color.clear
      } else {
        WidgetBackgroundView(palette: palette)
      }
    }
    .widgetURL(URL(string: "lantern://widget"))
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

// MARK: - Shared pieces

private struct StatusDot: View {
  let palette: WidgetPalette
  var size: CGFloat = 8

  var body: some View {
    Circle()
      .fill(palette.statusDot)
      .frame(width: size, height: size)
      .shadow(color: palette.statusDot.opacity(0.6), radius: palette.isOn ? 4 : 0)
      .widgetAccentable()
  }
}

/// Status line: dot + title, greyed while an intent is in flight.
private struct StatusLine: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette
  var font: Font = .headline

  var body: some View {
    HStack(spacing: 6) {
      StatusDot(palette: palette)
      Text(presentation.title)
        .font(font)
        .foregroundStyle(palette.textPrimary)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .invalidatableContent()
    }
  }
}

/// Location line with flag; falls back to the CTA copy when disconnected.
private struct LocationLine: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette
  var font: Font = .caption

  var body: some View {
    HStack(spacing: 4) {
      if presentation.state.status == .connected || presentation.state.status == .connecting,
        let flag = presentation.flag
      {
        Text(flag).font(font)
      } else {
        Image(systemName: "location.fill")
          .font(font.weight(.semibold))
          .imageScale(.small)
      }
      Text(presentation.subtitle)
        .font(font)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
    .foregroundStyle(palette.textSecondary)
  }
}

/// Primary control. A plain button with an explicit capsule so colors are
/// exactly the palette's (borderedProminent re-tints inside widgets), sized
/// by minHeight rather than padding so it can never overflow its column.
private struct ActionButton: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette
  var minHeight: CGFloat = 34

  private var busy: Bool { presentation.state.status.isTransitioning }

  var body: some View {
    Button(intent: ToggleVPNIntent()) {
      HStack(spacing: 6) {
        if busy {
          ProgressView()
            .controlSize(.small)
            .tint(palette.buttonText)
        } else {
          Image(systemName: "power")
            .font(.caption.weight(.bold))
        }
        Text(presentation.actionTitle)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .foregroundStyle(palette.buttonText)
      .frame(maxWidth: .infinity, minHeight: minHeight)
      .background(
        Capsule()
          .fill(palette.buttonFill)
          .overlay(Capsule().strokeBorder(palette.buttonStroke, lineWidth: 1))
      )
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .disabled(busy)
    .invalidatableContent()
  }
}

/// Round power button for the medium layout's right column.
private struct PowerButton: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette

  private var busy: Bool { presentation.state.status.isTransitioning }

  var body: some View {
    Button(intent: ToggleVPNIntent()) {
      ZStack {
        Circle()
          .fill(palette.buttonFill)
          .overlay(Circle().strokeBorder(palette.buttonStroke, lineWidth: 2))
          .shadow(color: palette.accentHighlight.opacity(palette.isOn ? 0.45 : 0), radius: 10)
        if busy {
          ProgressView()
            .tint(palette.buttonText)
        } else {
          Image(systemName: "power")
            .font(.title2.weight(.bold))
            .foregroundStyle(palette.buttonText)
        }
      }
      .aspectRatio(1, contentMode: .fit)
      .contentShape(Circle())
    }
    .buttonStyle(.plain)
    .disabled(busy)
    .invalidatableContent()
    .accessibilityLabel(Text(presentation.actionTitle))
  }
}

// MARK: - Home screen

private struct SmallLayout: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: presentation.symbolName)
          .font(.title3.weight(.semibold))
          .foregroundStyle(palette.accentForeground)
          .widgetAccentable()
        Spacer(minLength: 0)
        Text("Lantern")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(palette.accentForeground)
      }

      Spacer(minLength: 2)

      StatusLine(presentation: presentation, palette: palette, font: .subheadline.weight(.semibold))
      LocationLine(presentation: presentation, palette: palette, font: .caption2)

      Spacer(minLength: 6)

      ActionButton(presentation: presentation, palette: palette, minHeight: 30)
    }
  }
}

private struct MediumLayout: View {
  let presentation: VPNWidgetPresentation
  let palette: WidgetPalette

  var body: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Image(systemName: presentation.symbolName)
            .font(.subheadline.weight(.semibold))
            .widgetAccentable()
          Text("Lantern VPN")
            .font(.caption.weight(.semibold))
        }
        .foregroundStyle(palette.accentForeground)

        Spacer(minLength: 0)

        StatusLine(presentation: presentation, palette: palette, font: .title3.weight(.bold))
        LocationLine(presentation: presentation, palette: palette, font: .footnote)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      PowerButton(presentation: presentation, palette: palette)
        .frame(maxHeight: .infinity)
        .frame(maxWidth: 72)
    }
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
    .disabled(presentation.state.status.isTransitioning)
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
          Text(presentation.locationText)
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
      .disabled(presentation.state.status.isTransitioning)
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
