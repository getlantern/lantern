import FlutterMacOS
import OSLog

@main
class AppDelegate: FlutterAppDelegate {
  let logger = Logger(subsystem: "org.getlantern.lantern", category: "AppDelegate")

    /*
  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    //let systemExtensionManager = SystemExtensionManager()
    //systemExtensionManager.activateExtension()
    super.applicationDidFinishLaunching(aNotification)
  }
     */

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

}
  
