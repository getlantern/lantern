import Cocoa
import FlutterMacOS
import Liblantern

@main
class AppDelegate: FlutterAppDelegate {
  private let vpnManager = VPNManager.shared
  private var methodHandler: MethodHandler?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Get the FlutterViewController
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      fatalError("contentViewController is not a FlutterViewController")
    }

    // Register event handlers

    registerEventHandlers(controller: controller)

    // Setup native method channel
    setupMethodHandler(controller: controller)

    // Initialize directories and working paths
    setupFileSystem()

    // Set radiance (your custom logic)
    setupRadiance()

    super.applicationDidFinishLaunching(notification)
  }

  /// Registers Flutter event channel handlers
  private func registerEventHandlers(controller: FlutterViewController) {
    let registry = controller as! FlutterPluginRegistry
    let statusRegistrar = registry.registrar(forPlugin: "StatusEventHandler")
    StatusEventHandler.register(with: statusRegistrar)

    let logsRegistrar = registry.registrar(forPlugin: "LogsEventHandler")
    LogsEventHandler.register(with: logsRegistrar)
  }

  /// Initializes the native method channel handler
  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.engine.binaryMessenger
    )
    methodHandler = MethodHandler(channel: nativeChannel, vpnManager: vpnManager)
  }

  /// Prepares the file system directories for use
  private func setupFileSystem() {
    do {
      try FileManager.default.createDirectory(
        at: FilePath.workingDirectory,
        withIntermediateDirectories: true
      )
    } catch {
      appLogger.error("Failed to create working directory: \(error.localizedDescription)")
    }

    guard FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path) else {
      appLogger.error("Failed to change current directory to: \(FilePath.sharedDirectory.path)")
      return
    }

  }

  /// Calls API handler setup
  private func setupRadiance() {
    Task {
      // Set up the base directory and options
      let baseDir = FilePath.workingDirectory.relativePath
      let opts = MobileOpts()
      opts.dataDir = baseDir
      opts.deviceid = "KDFHDJB5"
      opts.locale = Locale.current.identifier
      var error: NSError?
      await MobileSetupRadiance(opts, &error)
      // Handle any error returned by the setup
      if let error {
        appLogger.error("Error while setting up radiance: \(error)")
      }
    }
  }
}
