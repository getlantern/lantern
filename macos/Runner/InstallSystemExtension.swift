import SwiftUI

@_cdecl("installSystemExtension")
public func installSystemExtension() {
    print(">>> installSystemExtension\n")
    Task {
        do {
            if let result = try await SystemExtension.install() {
                if result == .willCompleteAfterReboot {
                    // Show an alert to the user indicating that a reboot is required
                    // and that the system extension will be installed after the reboot.
                    print(">>> System extension will be installed after reboot")
                    // Show an alert to the user indicating that a reboot is required
                    // and that the system extension will be installed after the reboot.
                    //alert = Alert(title: Text("System Extension Installation"), message: Text("System extension will be installed after reboot"))
                    

                    //Alert(title: Text("System Extension Installation"), errorMessage: String(localized: "Need Reboot"))
                } else {
                    print("Other result: \(result)")
                }
            }
            //await callback()
        } catch {
            print("Catch error: \(error)")
            //alert = Alert(error)
        }
    }
}

