import FlutterMacOS
import OSLog
import app_links

@main
class AppDelegate: FlutterAppDelegate {

  private let systemExtensionManager = SystemExtensionManager.shared

  private let vpnManager = VPNManager.shared
  private var methodHandler: MethodHandler?

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

    // Load the liblantern.dylib
    if !LanternFFI.shared.loadLibrary() {
      appLogger.error("Failed to load liblantern.dylib")
    }

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

    let appStream = FlutterEventChannel(
      name: "org.getlantern.lantern/app_stream",
      binaryMessenger: controller.engine.binaryMessenger,
      codec: FlutterJSONMethodCodec.sharedInstance()
    )
    appStream.setStreamHandler(AppStreamHandler())
  }

  /// Initializes the native method channel handler
  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.engine.binaryMessenger
    )
    methodHandler = MethodHandler(channel: nativeChannel, vpnManager: vpnManager)
  }

  /// Calls API handler setup using FFI
  private func setupRadiance() {
    let startupTime = Date()
    let logDir = FilePath.logsDirectory.relativePath
    let dataDir = FilePath.dataDirectory.relativePath
    let locale = Locale.current.identifier
    let telemetryConsent = FilePath.isTelemetryEnabled()

    appLogger.info(
      "logging to \(logDir) dataDir: \(dataDir) telemetryConsent: \(telemetryConsent) locale: \(locale)"
    )

    do {
      try LanternFFI.shared.setupRadiance(
        logDir: logDir,
        dataDir: dataDir,
        locale: locale,
        telemetryConsent: telemetryConsent
      )
      appLogger.info("Radiance setup took \(Date().timeIntervalSince(startupTime)) seconds")
    } catch {
      appLogger.error("Error while setting up radiance: \(error.localizedDescription)")
    }
  }

}
