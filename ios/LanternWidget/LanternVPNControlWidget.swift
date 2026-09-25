//
//  LanternVPNControlWidget.swift
//  LanternWidget
//
//  iOS 18 Control Center / Lock Screen / Action button toggle.
//

import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct LanternVPNControlWidget: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: VPNWidgetStore.controlKind,
      provider: VPNControlValueProvider()
    ) { isOn in
      ControlWidgetToggle(
        "Lantern VPN",
        isOn: isOn,
        action: SetVPNStateIntent()
      ) { on in
        Label(on ? "Connected" : "Disconnected", systemImage: on ? "shield.fill" : "shield")
      }
      .tint(Color("WidgetAccent"))
    }
    .displayName("Lantern VPN")
    .description("Connect or disconnect Lantern.")
  }
}

@available(iOS 18.0, *)
struct VPNControlValueProvider: ControlValueProvider {
  var previewValue: Bool { true }

  func currentValue() async throws -> Bool {
    await WidgetTunnelController.reconciledState().status.isOn
  }
}
