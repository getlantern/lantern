import Cocoa
import Darwin

struct SmokeError: Error { let message: String }

struct SystemExtensionSmokeCommand {
  static func parse(arguments: [String]) -> Result<SystemExtensionSmokeCommand?, SmokeError> {
    if arguments.contains("--invalid") { return .failure(SmokeError(message: "invalid")) }
    return .success(arguments.contains("--smoke") ? SystemExtensionSmokeCommand() : nil)
  }
  static func writeStdout(_ text: String) { print(text) }
  static func errorJSON(_ text: String) -> String { text }
}

struct FilePath {
  static func setupFileSystem() { print("filesystem") }
}

struct SystemExtensionManager {
  static var shared: Self {
    print("extension-manager")
    return Self()
  }
}

final class SystemExtensionSmokeCommandRunner {
  init(
    command: SystemExtensionSmokeCommand, manager: SystemExtensionManager,
    output: (String) -> Void, complete: (Int32) -> Void
  ) {}
  func start() {
    print("smoke")
    exit(0)
  }
}

struct AppInstallationPreflight {
  static func run() -> Bool {
    print("preflight")
    return ProcessInfo.processInfo.environment["ALLOW_STARTUP"] == "1"
  }
}

// swift-format-ignore: AlwaysUseLowerCamelCase
func NSApplicationMain(
  _ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
) -> Int32 {
  print("application-bootstrap")
  return 0
}
