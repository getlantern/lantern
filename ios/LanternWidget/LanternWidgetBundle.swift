//
//  LanternWidgetBundle.swift
//  LanternWidget
//

import SwiftUI
import WidgetKit

@main
struct LanternWidgetBundle: WidgetBundle {
  var body: some Widget {
    LanternVPNWidget()
    controls
  }

  @WidgetBundleBuilder
  private var controls: some Widget {
    if #available(iOS 18.0, *) {
      LanternVPNControlWidget()
    }
  }
}
