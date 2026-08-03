import Cocoa
import Combine
import FlutterMacOS
import IOKit.ps

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    let project = FlutterDartProject()
    project.dartEntrypointArguments = Array(ProcessInfo.processInfo.arguments.dropFirst())
    let flutterViewController = FlutterViewController(project: project)

    let size = NSSize(width: 390, height: 760)

    self.setContentSize(size)
    self.minSize = size
    self.maxSize = size
    self.styleMask.remove(.resizable)
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = true
    self.center()

    self.contentViewController = flutterViewController
    RegisterGeneratedPlugins(registry: flutterViewController)
    super.awakeFromNib()
  }
}
