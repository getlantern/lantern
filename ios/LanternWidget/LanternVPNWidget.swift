//
//  LanternVPNWidget.swift
//  LanternWidget
//
//  Home and Lock Screen widget showing the VPN state with a connect/disconnect
//  button. Event driven: the app and tunnel publish VPNWidgetState and reload
//  the timeline, so the provider never polls and returns a single entry.
//

import SwiftUI
import WidgetKit

struct VPNWidgetEntry: TimelineEntry {
  let date: Date
  let state: VPNWidgetState

  static let placeholder = VPNWidgetEntry(
    date: Date(),
    state: VPNWidgetState(
      status: .connected, serverName: "auto", locationName: "New York, U.S.A",
      city: "New York", country: "U.S.A", countryCode: "US", updatedAt: Date()))
}

struct VPNTimelineProvider: TimelineProvider {
  /// Updates are pushed by the app and tunnel; scheduled refreshes only catch
  /// writes that never happened, and each one counts against WidgetKit's
  /// daily reload budget (~40-70).
  private static let transitionRecheck: TimeInterval = 5 * 60
  /// Catches a tunnel killed while the app is suspended (nobody writes then).
  private static let connectedRecheck: TimeInterval = 60 * 60

  /// Disconnected never refreshes: any start goes through startTunnel, which publishes.
  private static func policy(for state: VPNWidgetState) -> TimelineReloadPolicy {
    switch state.status {
    case .connecting, .disconnecting:
      return .after(Date().addingTimeInterval(transitionRecheck))
    case .connected:
      return .after(Date().addingTimeInterval(connectedRecheck))
    case .disconnected:
      return .never
    }
  }

  func placeholder(in context: Context) -> VPNWidgetEntry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (VPNWidgetEntry) -> Void) {
    if context.isPreview {
      completion(.placeholder)
      return
    }
    Task { completion(await current()) }
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<VPNWidgetEntry>) -> Void)
  {
    Task {
      let entry = await current()
      completion(Timeline(entries: [entry], policy: Self.policy(for: entry.state)))
    }
  }

  private func current() async -> VPNWidgetEntry {
    VPNWidgetEntry(date: Date(), state: await WidgetTunnelController.reconciledState())
  }
}

struct LanternVPNWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: VPNWidgetStore.widgetKind, provider: VPNTimelineProvider()) { entry in
      LanternWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("Lantern VPN")
    .description("See your connection and connect or disconnect with one tap.")
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryCircular,
      .accessoryRectangular,
      .accessoryInline,
    ])
  }
}

#Preview("Small", as: .systemSmall) {
  LanternVPNWidget()
} timeline: {
  VPNWidgetEntry(date: .now, state: VPNWidgetEntry.placeholder.state.with(status: .disconnected))
  VPNWidgetEntry(date: .now, state: VPNWidgetEntry.placeholder.state.with(status: .connecting))
  VPNWidgetEntry.placeholder
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .disconnected, serverName: "auto", updatedAt: .now))
}

#Preview("Medium", as: .systemMedium) {
  LanternVPNWidget()
} timeline: {
  VPNWidgetEntry(date: .now, state: VPNWidgetEntry.placeholder.state.with(status: .disconnected))
  VPNWidgetEntry.placeholder
}

extension VPNWidgetState {
  fileprivate func with(status: VPNWidgetStatus) -> VPNWidgetState {
    var copy = self
    copy.status = status
    return copy
  }
}

#Preview("Lock screen", as: .accessoryRectangular) {
  LanternVPNWidget()
} timeline: {
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .connected, serverName: "auto", updatedAt: .now))
}
