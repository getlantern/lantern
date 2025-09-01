import NetworkExtension
import OSLog

public class PacketTunnelProvider: ExtensionProvider {

  public override func startTunnel(options: [String: NSObject]?) async throws {
    appLogger.log("PacketTunnelProvider starting tunnel")
    try await super.startTunnel(options: options)
  }

  public override func stopTunnel(with reason: NEProviderStopReason) async {
    appLogger.log("PacketTunnelProvider stopping tunnel with reason: \(reason.rawValue)")
    await super.stopTunnel(with: reason)
  }
}
