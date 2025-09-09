import FlutterMacOS
import Liblantern
import OSLog
import app_links

@main
class AppDelegate: FlutterAppDelegate {

  private let systemExtensionManager = SystemExtensionManager.shared

  private let vpnManager = VPNManager.shared

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      fatalError("contentViewController is not a FlutterViewController")
    }

    registerEventHandlers(controller: controller)
    // Initialize directories and working paths
    setupFileSystem()

    setupRadiance(controller: controller)

    NSSetUncaughtExceptionHandler { exception in
      print(exception.reason ?? "Unknown exception reason")
      print(exception.callStackSymbols)
    }
  }

  override func applicationDidFinishLaunching(_ aNotification: Notification) {
    systemExtensionManager.activateExtension()
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

  }

  /// Calls API handler setup
  private func setupRadiance(controller: FlutterViewController) {
    appLogger.info("Setting up radiance")
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
      let core = LanterncoreNew(opts)
      // Setup native method channel
      let nativeChannel = await FlutterMethodChannel(
        name: "org.getlantern.lantern/method",
        binaryMessenger: controller.engine.binaryMessenger
      )
      _ = MethodHandler(
        channel: nativeChannel, vpnManager: vpnManager, core: core as! LanterncoreCore)
    }
  }
}
