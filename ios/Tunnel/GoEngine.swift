import Foundation

@_silgen_name("ProcessInboundPacket")
func ProcessInboundPacket(_ packetPtr: UnsafeRawPointer?, _ length: CInt) -> Void

class GoEngine {
    func processInboundPacket(_ packet: Data) {
        packet.withUnsafeBytes { rawBuf in
            guard let baseAddress = rawBuf.baseAddress else { return }
            ProcessInboundPacket(baseAddress, CInt(packet.count))
        }
    }
}
