import Foundation
import Libbox
import NetworkExtension
import UserNotifications
#if os(macOS)
    import CoreWLAN
#endif

public class ExtensionPlatformInterface: NSObject, LibboxPlatformInterfaceProtocol, LibboxCommandServerHandlerProtocol {
    //private let tunnel: ExtensionProvider
    private var networkSettings: NEPacketTunnelNetworkSettings?

    init(_ tunnel: ExtensionProvider) {
        self.tunnel = tunnel
    }

    public func openTun(_ options: LibboxTunOptionsProtocol?, ret0_: UnsafeMutablePointer<Int32>?) throws {

    }

    public func usePlatformAutoDetectControl() -> Bool {
        false
    }

    public func autoDetectControl(_: Int32) throws {}

    public func findConnectionOwner(_: Int32, sourceAddress _: String?, sourcePort _: Int32, destinationAddress _: String?, destinationPort _: Int32, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "not implemented", code: 0)
    }

    public func packageName(byUid _: Int32, error _: NSErrorPointer) -> String {
        ""
    }

    public func uid(byPackageName _: String?, ret0_ _: UnsafeMutablePointer<Int32>?) throws {
        throw NSError(domain: "not implemented", code: 0)
    }

    public func useProcFS() -> Bool {
        false
    }

    public func writeLog(_ message: String?) {
    }

    private var nwMonitor: NWPathMonitor? = nil

    public func startDefaultInterfaceMonitor(_ listener: LibboxInterfaceUpdateListenerProtocol?) throws {
       
    }

    public func closeDefaultInterfaceMonitor(_: LibboxInterfaceUpdateListenerProtocol?) throws {
    }

    public func getInterfaces() throws -> LibboxNetworkInterfaceIteratorProtocol {
        
    }

    public func underNetworkExtension() -> Bool {
        true
    }

    public func includeAllNetworks() -> Bool {
    }

    public func clearDNSCache() {
        
    }

    public func readWIFIState() -> LibboxWIFIState? {
    
    }

    public func serviceReload() throws {
    }

    public func postServiceClose() {
    }

    public func getSystemProxyStatus() -> LibboxSystemProxyStatus? {

    }

    public func setSystemProxyEnabled(_ isEnabled: Bool) throws {
        
    }

    func reset() {

    }

    public func send(_ notification: LibboxNotification?) throws {
        
    }
}
