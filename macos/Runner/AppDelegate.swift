import FlutterMacOS
import Liblantern
import OSLog
import app_links

@main
class AppDelegate: FlutterAppDelegate {

  private let systemExtensionManager = SystemExtensionManager.shared

  private let vpnManager = VPNManager.shared

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      fatalError("contentViewController is not a FlutterViewController")
    }

    registerEventHandlers(controller: controller)

    // Initialize directories and working paths
    setupFileSystem()

    setupRadiance()

    // Setup native method channel
    setupMethodHandler(controller: controller)

    NSSetUncaughtExceptionHandler { exception in
      print(exception.reason ?? "Unknown exception reason")
      print(exception.callStackSymbols)
    }
    
      SystemExtensionManager.shared.activateExtension()
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
    let registry = controller as FlutterPluginRegistry
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
        at: FilePath.logsDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("logs directory created at: \(FilePath.logsDirectory.path)")
    } catch {
      appLogger.error("Failed to create logs directory: \(error.localizedDescription)")
    }
    do {
      try FileManager.default.createDirectory(
        at: FilePath.dataDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("data directory created at: \(FilePath.dataDirectory.path)")
    } catch {
      appLogger.error("Failed to create data directory: \(error.localizedDescription)")
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
      let opts = UtilsOpts()
      opts.dataDir = FilePath.dataDirectory.relativePath
      opts.logDir = FilePath.logsDirectory.relativePath
      appLogger.info("Data directory: " + opts.dataDir)
      appLogger.info("Log directory: " + opts.logDir)
      opts.deviceid = ""
      opts.logLevel = "debug"
      appLogger.info("Log level: " + opts.logLevel)

      opts.locale = Locale.current.identifier
      var error: NSError?
      MobileSetupRadiance(opts, &error)
      // Handle any error returned by the setup
      if let error {
        appLogger.error("Error while setting up radiance: \(error)")
      } else {
        appLogger.info("Radiance setup complete")
      }
    }
  }

}
