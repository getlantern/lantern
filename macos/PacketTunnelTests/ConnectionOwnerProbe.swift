import Foundation
import Liblantern

@main
enum ConnectionOwnerProbe {
  static func main() throws {
    let args = CommandLine.arguments
    guard args.count == 6, let ipProtocol = Int32(args[1]), let sourcePort = Int32(args[3]),
      let destinationPort = Int32(args[5])
    else { exit(2) }

    let platform: UtilsPlatformInterfaceProtocol = ExtensionPlatformInterface(ExtensionProvider())
    do {
      let owner = try platform.findConnectionOwner(
        ipProtocol, sourceAddress: args[2], sourcePort: sourcePort,
        destinationAddress: args[4], destinationPort: destinationPort)
      let data = try JSONSerialization.data(withJSONObject: [
        "userId": owner.userId, "processPath": owner.processPath,
      ])
      FileHandle.standardOutput.write(data)
    } catch {
      FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
      exit(1)
    }
  }
}
