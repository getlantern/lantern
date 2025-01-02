import Foundation
import os

@_cdecl("swift_log")
func swift_log(_ message: UnsafePointer<CChar>) {
    let logMessage = String(cString: message)
    os_log("[Go]: \(logMessage)")
}
