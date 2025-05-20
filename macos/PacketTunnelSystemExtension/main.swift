import Foundation
import NetworkExtension

autoreleasepool {
    let log = PacketTunnelProvider.logger
    log.log(level: .info, "FIRST LIGHT")
    NEProvider.startSystemExtensionMode()
}

dispatchMain()
