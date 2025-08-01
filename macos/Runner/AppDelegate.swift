import FlutterMacOS
import Liblantern
import OSLog
import app_links

@main
class AppDelegate: FlutterAppDelegate {

  private let vpnManager = VPNManager.shared

  // Close app when last window is closed
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // Disable secure state restoration
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return false
  }

  // MARK: — Disable all state restoration —

  @objc func applicationShouldRestoreApplicationState(_ app: NSApplication) -> Bool {
    return false
  }
  @objc func applicationShouldRestoreWindowState(_ app: NSApplication, window: NSWindow) -> Bool {
    return false
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    // Ensure Flutter window is key and visible
    if let window = mainFlutterWindow {
      window.makeKeyAndOrderFront(nil)
    }

    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      fatalError("contentViewController is not a FlutterViewController")
    }
    RegisterGeneratedPlugins(registry: controller)

    // Register event handlers
    registerEventHandlers(controller: controller)

    // Setup native method channel
    setupMethodHandler(controller: controller)

    // Initialize directories and working paths
    setupFileSystem()

    // set radiance
    setupRadiance()
    // Catch uncaught exceptions
    NSSetUncaughtExceptionHandler { exception in
      print(exception.reason ?? "Unknown reason")
      print(exception.callStackSymbols)
    }
    super.applicationDidFinishLaunching(aNotification)
  }

  public override func application(
    _ application: NSApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void
  ) -> Bool {

    guard let url = AppLinks.shared.getUniversalLink(userActivity) else {
      return false
    }

    AppLinks.shared.handleLink(link: url.absoluteString)
    return false
  }

  /// Registers Flutter event channel handlers
  private func registerEventHandlers(controller: FlutterViewController) {
    let registry = controller as! FlutterPluginRegistry
    let statusRegistrar = registry.registrar(forPlugin: "StatusEventHandler")
    StatusEventHandler.register(with: statusRegistrar)

    //      if let registrar = self.registrar(forPlugin: "LogsEventHandler") {
    //        LogsEventHandler.register(with: registrar)
    //      }

    let privateStatusRegistrar = registry.registrar(forPlugin: "PrivateServerEventHandler")
    PrivateServerEventHandler.register(with: privateStatusRegistrar)

  }

  /// Initializes the native method channel handler
  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.engine.binaryMessenger
    )
    MethodHandler(channel: nativeChannel, vpnManager: vpnManager)
  }

  /// Prepares the file system directories for use
  private func setupFileSystem() {
    do {

      try FileManager.default.createDirectory(
        at: FilePath.sharedDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("Shared directory created at: \(FilePath.sharedDirectory.path)")
      try FileManager.default.createDirectory(
        at: FilePath.logsDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("logs directory created at: \(FilePath.workingDirectory.path)")
    } catch {
      appLogger.error("Failed to create working directory: \(error.localizedDescription)")
    }

    guard FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path) else {
      appLogger.error("Failed to change current directory to: \(FilePath.sharedDirectory.path)")
      return
    }
    appLogger.info("Current directory changed to: \(FilePath.sharedDirectory.path)")

  }

  /// Calls API handler setup
  private func setupRadiance() {
    Task {
      // Set up the base directory and options
      let baseDir = FilePath.workingDirectory.relativePath
      let opts = UtilsOpts()
      opts.dataDir = baseDir
      opts.deviceid = ""
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
