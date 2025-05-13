import NetworkExtension

autoreleasepool {
    //let log = PacketTunnelProvider.log
    print("First light in SystemExtension main!")
    NEProvider.startSystemExtensionMode()
}
dispatchMain()

