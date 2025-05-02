import NetworkExtension
 
func main() -> Never {
    autoreleasepool {
        let log = PacketTunnelProvider.log
        log.log(level: .debug, "first light")
        NEProvider.startSystemExtensionMode()
    }
    dispatchMain()
}
 
main()
