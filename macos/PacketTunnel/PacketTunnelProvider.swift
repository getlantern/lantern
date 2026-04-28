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

  public override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?)
  {
    appLogger.info("PacketTunnelProvider received app message with data: \(messageData)")
    func respond(_ dict: [String: Any]) {
      appLogger.info("PacketTunnelProvider responding with: \(dict)")
      let data = try? JSONSerialization.data(withJSONObject: dict)
      completionHandler?(data)
    }

    guard
      let json = try? JSONSerialization.jsonObject(with: messageData) as? [String: Any],
      let method = json["method"] as? String,
      let params = json["params"] as? [String: Any]
    else {
      appLogger.error("PacketTunnelProvider received invalid message format")
      return respond(["error": "Invalid message format"])
    }

    appLogger.info("PacketTunnelProvider handling method: \(method) with params: \(params)")

    switch method {
    case "PrivateServer":
      appLogger.info("Received connectServer command with params: \(params)")
      guard let server = params["server"] as? String else {
        return respond(["error": "Missing parameters"])
      }
      appLogger.info("Connecting to server \(server)")
      connectToServer(serverName: server) { success, errorMessage in
        if success {
          respond(["result": "Connected to \(server)"])
        } else {
          respond(["error": errorMessage ?? "Unknown error"])
        }
      }
      break
    case "Lantern":
      appLogger.info("Received Lantern command")
        appLogger.info("VPN already active connecting to Lantern/auto")
        connectToServer(serverName: "auto") { success, errorMessage in
          if success {
            respond(["result": "Connected to auto tag"])
          } else {
            respond(["error": errorMessage ?? "Unknown error"])
          }
        }

    default:
      respond(["error": "Unknown method"])
    }
  }

}
