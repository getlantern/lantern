import Cocoa
import Combine
import FlutterMacOS
import IOKit.ps

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    super.awakeFromNib()
  }
}

