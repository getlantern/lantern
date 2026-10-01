import ApplicationServices
import Foundation

// Flutter drives Lantern's UI. This helper uses Accessibility for Sparkle's
// native buttons and the window check after relaunch.
private let installButtonNames = ["Install Update", "Install and Relaunch"]

private struct SmokeError: Error, CustomStringConvertible {
  let description: String
  init(_ description: String) { self.description = description }
}

private func checkAccess() throws {
  guard AXIsProcessTrusted() else {
    throw SmokeError("Allow the active Runner.Listener in System Settings > Privacy & Security > Accessibility.")
  }
  // Bound individual AX calls as well as the polling loop.
  let result = AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)
  guard result == .success else {
    throw SmokeError("Could not set the Accessibility timeout: \(result.rawValue)")
  }
}

private func attribute<T>(_ element: AXUIElement, _ name: String) throws -> T? {
  var value: CFTypeRef?
  let result = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  switch result {
  case .success:
    return value as? T
  case .noValue, .attributeUnsupported, .invalidUIElement, .cannotComplete:
    // Windows and controls can disappear while Sparkle changes stages.
    return nil
  default:
    throw SmokeError("Could not read \(name): Accessibility error \(result.rawValue)")
  }
}

private func installButton(in app: AXUIElement, deadline: TimeInterval) throws -> (AXUIElement, String)? {
  var pending: [AXUIElement] = try attribute(app, kAXWindowsAttribute) ?? []
  while let element = pending.popLast() {
    guard ProcessInfo.processInfo.systemUptime < deadline else { return nil }
    let role: String? = try attribute(element, kAXRoleAttribute)
    if role == kAXButtonRole,
       let title: String = try attribute(element, kAXTitleAttribute),
       installButtonNames.contains(title),
       try attribute(element, kAXEnabledAttribute) == true {
      return (element, title)
    }
    let children: [AXUIElement] = try attribute(element, kAXChildrenAttribute) ?? []
    pending.append(contentsOf: children)
  }
  return nil
}

private func hasMainWindow(_ app: AXUIElement) throws -> Bool {
  let hidden: Bool? = try attribute(app, kAXHiddenAttribute)
  guard hidden == false else { return false }
  let windows: [AXUIElement] = try attribute(app, kAXWindowsAttribute) ?? []
  for window in windows {
    let subrole: String? = try attribute(window, kAXSubroleAttribute)
    let minimized: Bool? = try attribute(window, kAXMinimizedAttribute)
    if subrole == kAXStandardWindowSubrole && minimized == false { return true }
  }
  return false
}

private func run(_ arguments: [String]) throws {
  if arguments == ["check-access"] {
    try checkAccess()
    print("native UI automation ready")
    return
  }
  guard arguments.count == 3,
        ["wait-prompt", "install-until-exit", "wait-main"].contains(arguments[0]),
        let pid = pid_t(arguments[1]), pid > 0,
        let timeout = TimeInterval(arguments[2]), timeout.isFinite, timeout > 0 else {
    throw SmokeError("Expected check-access, or an action (wait-prompt, install-until-exit, wait-main), positive PID and timeout.")
  }
  try checkAccess()
  let action = arguments[0]
  let app = AXUIElementCreateApplication(pid)
  let deadline = ProcessInfo.processInfo.systemUptime + timeout
  var pressedButtons = Set<String>()
  while ProcessInfo.processInfo.systemUptime < deadline {
    if kill(pid, 0) != 0 && errno == ESRCH {
      guard action == "install-until-exit" else {
        throw SmokeError("Process \(pid) exited before \(action) completed.")
      }
      print("original process exited")
      return
    }
    if action == "wait-main" {
      if try hasMainWindow(app) {
        print("main window ready")
        return
      }
    } else if let (button, title) = try installButton(in: app, deadline: deadline) {
      if action == "wait-prompt" {
        print(title)
        return
      }
      if !pressedButtons.contains(title) {
        let result = AXUIElementPerformAction(button, kAXPressAction as CFString)
        guard result == .success else {
          throw SmokeError("Could not press \(title): Accessibility error \(result.rawValue)")
        }
        pressedButtons.insert(title)
        print("[E2E] pressed Sparkle \(title)")
      }
    }
    Thread.sleep(forTimeInterval: 0.5)
  }
  throw SmokeError("Timed out waiting for \(action) in process \(pid).")
}

do {
  try run(Array(CommandLine.arguments.dropFirst()))
} catch {
  FileHandle.standardError.write(Data("\(error)\n".utf8))
  exit(1)
}
