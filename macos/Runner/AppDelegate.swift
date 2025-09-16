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

    let systemExtensionStatusRegistrar = registry.registrar(
      forPlugin: "SystemExtensionStatusEventHandler")
    SystemExtensionStatusEventHandler.register(with: systemExtensionStatusRegistrar)

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

    // Setup shared directory
    do {
      try FileManager.default.createDirectory(
        at: FilePath.dataDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("data directory created at: \(FilePath.dataDirectory.path)")
    } catch {
      appLogger.error("Failed to create data directory: \(error.localizedDescription)")
    }

    //Setup log directory
    do {
      try FileManager.default.createDirectory(
        at: FilePath.logsDirectory,
        withIntermediateDirectories: true
      )
      appLogger.info("logs directory created at: \(FilePath.logsDirectory.path)")
    } catch {
      appLogger.error("Failed to create logs directory: \(error.localizedDescription)")
    }

  }

  /// Calls API handler setup
  private func setupRadiance() {
    let startupTime = Date()
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    opts.logDir = FilePath.logsDirectory.relativePath
    opts.deviceid = ""
    opts.logLevel = "debug"
    opts.locale = Locale.current.identifier
    appLogger.info("logging to \(opts.logDir) dataDir: \(opts.dataDir) logLevel: \(opts.logLevel)")
    var error: NSError?
    MobileSetupRadiance(opts, &error)
    // Handle any error returned by the setup
    if let error {
      appLogger.error("Error while setting up radiance: \(error)")
    } else {
      appLogger.info("Radiance setup took \(Date().timeIntervalSince(startupTime)) seconds")
    }
  }

}
