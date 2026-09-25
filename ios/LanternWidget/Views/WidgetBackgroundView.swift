//
//  WidgetBackgroundView.swift
//  LanternWidget
//

import SwiftUI

/// Solid dark card behind the home screen families.
struct WidgetBackgroundView: View {
  let palette: WidgetPalette

  var body: some View {
    palette.background
  }
}
