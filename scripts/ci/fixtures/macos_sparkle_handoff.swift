import AppKit

// A small native window exercises the driver without installing Lantern.
final class Fixture: NSObject, NSApplicationDelegate {
  let mode = CommandLine.arguments[1]
  var window: NSWindow!
  var installButton: NSButton!

  func applicationDidFinishLaunching(_ notification: Notification) {
    if mode == "no-window" { return }
    window = NSWindow(
      contentRect: NSRect(x: 200, y: 200, width: 320, height: 160),
      styleMask: [.titled, .closable, .miniaturizable],
      backing: .buffered, defer: false)
    window.title = "Lantern updater driver test"
    let stack = NSStackView()
    stack.orientation = .vertical
    stack.frame = NSRect(x: 20, y: 20, width: 280, height: 120)
    window.contentView!.addSubview(stack)
    installButton = NSButton(title: "Install Update", target: self, action: #selector(install))
    installButton.isEnabled = mode == "install"
    stack.addArrangedSubview(installButton)
    stack.addArrangedSubview(NSButton(title: "Cancel", target: self, action: #selector(unexpectedPress)))
    window.makeKeyAndOrderFront(nil)
    NSApp.activate()
  }

  @objc func install() {
    if installButton.title == "Install Update" {
      installButton.title = "Install and Relaunch"
    } else {
      // Let AXPress return before the process exits.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { NSApp.terminate(nil) }
    }
  }

  @objc func unexpectedPress() { exit(2) }
}

let app = NSApplication.shared
let fixture = Fixture()
app.delegate = fixture
app.setActivationPolicy(.regular)
app.run()
