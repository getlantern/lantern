import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    override func applicationDidFinishLaunching(_ aNotification: Notification) {
        print("Initing VPNManagerViewModel")
        VPNManagerViewModel.init()
        // Activate extension on launch (consider user experience implications)

        // Observe notifications from SystemExtensionManager
        SystemExtensionManager.shared.activateExtension(bundleID: "org.getlantern.lantern.PacketTunnelSystemExtension")
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleNeedsUserApproval),
                                               name: .systemExtensionNeedsUserApproval,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleActivationSuccess),
                                               name: .systemExtensionActivationSucceeded,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleActivationFailure),
                                               name: .systemExtensionActivationFailed,
                                               object: nil)
    }

    @objc func handleNeedsUserApproval(notification: Notification) {
        guard let extensionID = notification.object as? String else { return }
        print("UI: System extension \(extensionID) needs user approval.")
        //Show an alert to the user:
        let alert = NSAlert()
        // TODO: internationalize this
        alert.messageText = "System Extension Approval Needed"
        alert.informativeText = "Your Mac requires you to approve the system extension for Lantern to function correctly. Please go to System Settings > Privacy & Security to allow it."
        alert.addButton(withTitle: "Open Privacy & Security")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            SystemExtensionManager.shared.openPrivacyAndSecuritySettings()
        }
    }

    @objc func handleActivationSuccess(notification: Notification) {
        guard let extensionID = notification.object as? String else { return }
        print("UI: System extension \(extensionID) activated successfully!")
        //Update UI, enable features, etc.
    }

    @objc func handleActivationFailure(notification: Notification) {
        guard let extensionID = notification.object as? String else { return }
        let error = notification.userInfo?["error"] as? Error
        print("UI: Failed to activate system extension \(extensionID). Error: \(error?.localizedDescription ?? "Unknown error")")
        //Show an error message to the user.
    }
}
