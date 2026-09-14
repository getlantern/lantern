import Cocoa
import Darwin

private var smokeCommandRunner: SystemExtensionSmokeCommandRunner?

switch SystemExtensionSmokeCommand.parse(arguments: ProcessInfo.processInfo.arguments) {
case .failure(let error):
  SystemExtensionSmokeCommand.writeStdout(SystemExtensionSmokeCommand.errorJSON(error.message))
  exit(64)
case .success(let command?):
  FilePath.setupFileSystem()
  smokeCommandRunner = SystemExtensionSmokeCommandRunner(
    command: command,
    manager: SystemExtensionManager.shared,
    output: SystemExtensionSmokeCommand.writeStdout,
    complete: { code in exit(code) }
  )
  smokeCommandRunner?.start()
  dispatchMain()
case .success(nil):
  #if !DEBUG
    // Nib loading creates the extension manager and starts Flutter.
    guard AppInstallationPreflight.run() else { exit(EXIT_SUCCESS) }
  #endif
  _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
}
