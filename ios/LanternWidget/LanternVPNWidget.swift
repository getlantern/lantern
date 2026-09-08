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
      status: .connected, serverName: "auto", locationName: "Frankfurt, Germany",
      countryCode: "DE", updatedAt: Date()))
}

struct VPNTimelineProvider: TimelineProvider {
  /// While a transition is in flight, re-check soon so a lost final write
  /// cannot leave the widget on "Disconnecting…" indefinitely.
  private static let transitionRecheck: TimeInterval = 8
  /// Idle safety net; normal updates are pushed via reloadTimelines.
  private static let idleRecheck: TimeInterval = 30 * 60

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
      let interval = entry.state.status.isTransitioning
        ? Self.transitionRecheck : Self.idleRecheck
      completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(interval))))
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
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .disconnected, serverName: "auto", updatedAt: .now))
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .connecting, serverName: "auto", updatedAt: .now))
  VPNWidgetEntry(
    date: .now,
    state: VPNWidgetState(
      status: .connected, serverName: "auto", locationName: "Frankfurt, Germany",
      countryCode: "DE", updatedAt: .now))
}

#Preview("Medium", as: .systemMedium) {
  LanternVPNWidget()
} timeline: {
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .disconnected, serverName: "auto", updatedAt: .now))
  VPNWidgetEntry(
    date: .now,
    state: VPNWidgetState(
      status: .connected, serverName: "auto", locationName: "Frankfurt, Germany",
      countryCode: "DE", updatedAt: .now))
}

#Preview("Lock screen", as: .accessoryRectangular) {
  LanternVPNWidget()
} timeline: {
  VPNWidgetEntry(
    date: .now, state: VPNWidgetState(status: .connected, serverName: "auto", updatedAt: .now))
}
