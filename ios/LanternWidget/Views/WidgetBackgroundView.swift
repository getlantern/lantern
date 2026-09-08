//
//  WidgetBackgroundView.swift
//  LanternWidget
//

import SwiftUI

/// Stateful background: teal gradient with a soft glow when the tunnel is
/// up, quiet neutral surface when it is down. Drawn with GeometryReader so
/// the ornament scales with every family instead of using fixed sizes.
struct WidgetBackgroundView: View {
  let palette: WidgetPalette

  var body: some View {
    GeometryReader { geo in
      let side = max(geo.size.width, geo.size.height)
      ZStack {
        LinearGradient(
          colors: [palette.backgroundTop, palette.backgroundBottom],
          startPoint: .topLeading,
          endPoint: .bottomTrailing)

        Circle()
          .fill(palette.glow)
          .frame(width: side * 0.9, height: side * 0.9)
          .blur(radius: side * 0.18)
          .offset(x: side * 0.25, y: -side * 0.35)

        Image(systemName: "shield.fill")
          .resizable()
          .scaledToFit()
          .foregroundStyle(palette.ornament)
          .frame(width: side * 0.75)
          .rotationEffect(.degrees(-12))
          .offset(x: side * 0.32, y: side * 0.28)
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .clipped()
    }
  }
}
