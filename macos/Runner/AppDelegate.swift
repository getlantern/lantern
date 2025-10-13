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
    FilePath.setupFileSystem()

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

    let flutterEventRegistrar = registry.registrar(forPlugin: "FlutterEventHandler")
    FlutterEventHandler.register(with: flutterEventRegistrar)

    let statusRegistrar = registry.registrar(forPlugin: "StatusEventHandler")
    StatusEventHandler.register(with: statusRegistrar)

    let systemExtensionStatusRegistrar = registry.registrar(
      forPlugin: "SystemExtensionStatusEventHandler")
    SystemExtensionStatusEventHandler.register(with: systemExtensionStatusRegistrar)

    let privateStatusRegistrar = registry.registrar(forPlugin: "PrivateServerEventHandler")
    PrivateServerEventHandler.register(with: privateStatusRegistrar)

    let logsRegistrar = registry.registrar(forPlugin: "LogsEventHandler")
    LogsEventHandler.register(with: logsRegistrar)
  }

  /// Initializes the native method channel handler
  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.engine.binaryMessenger
    )
    MethodHandler(channel: nativeChannel, vpnManager: vpnManager)
  }

  /// Calls API handler setup
  private func setupRadiance() {
    let startupTime = Date()
    let opts = UtilsOpts()
    opts.dataDir = FilePath.dataDirectory.relativePath
    opts.logDir = FilePath.logsDirectory.relativePath
    opts.deviceid = ""
    opts.logLevel = "trace"
    opts.locale = Locale.current.identifier
    appLogger.info("logging to \(opts.logDir) dataDir: \(opts.dataDir) logLevel: \(opts.logLevel)")
    var error: NSError?
    MobileSetupRadiance(opts, FlutterEventListener.shared, &error)
    // Handle any error returned by the setup
    if let error {
      appLogger.error("Error while setting up radiance: \(error)")
    } else {
      appLogger.info("Radiance setup took \(Date().timeIntervalSince(startupTime)) seconds")
    }
  }

}
