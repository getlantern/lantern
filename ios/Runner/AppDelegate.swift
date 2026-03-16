import Flutter
import Liblantern
import NetworkExtension
import UIKit
import app_links
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private let vpnManager = VPNManager.shared
  private var methodHandler: MethodHandler?

  // MARK: - FlutterImplicitEngineDelegate
  //
  // In Flutter 3.41+ the engine is initialised before the first scene connects,
  // so plugin registration and channel setup must happen here instead of in
  // application(_:didFinishLaunchingWithOptions:).  The window / root-view-
  // controller is not yet available at this point; use the messenger from the
  // engine bridge instead.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry

    // Register all Flutter plugins (replaces GeneratedPluginRegistrant call in
    // didFinishLaunchingWithOptions).
    GeneratedPluginRegistrant.register(with: registry)

    // Configure Flutter local notifications background isolate.
    notificationSetup()

    // Register custom event channel handlers.
    registerEventHandlers(registry: registry)

    // Set up the native method channel using the engine's binary messenger.
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    methodHandler = MethodHandler(channel: nativeChannel, vpnManager: vpnManager)
  }

  // MARK: - UIApplicationDelegate

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {

    // Initialize directories and working paths (no engine / window needed).
    setupFileSystem()

    // Start the Go backend.
    setupRadiance()

    NSSetUncaughtExceptionHandler { exception in
      print(exception.reason)
      print(exception.callStackSymbols)
    }

    // Handle cold-start deep links.
    if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
      AppLinks.shared.handleLink(url: url)
      return true  // Stop propagation to other packages.
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - Private helpers

  /// Registers Flutter event channel handlers using the plugin registry from
  /// the engine bridge (UIScene lifecycle compatible).
  private func registerEventHandlers(registry: FlutterPluginRegistry) {
    if let registrar = registry.registrar(forPlugin: "FlutterEventHandler") {
      FlutterEventHandler.register(with: registrar)
    }

    if let registrar = registry.registrar(forPlugin: "StatusEventHandler") {
      StatusEventHandler.register(with: registrar)
    }

    if let registrar = registry.registrar(forPlugin: "LogsEventHandler") {
      LogsEventHandler.register(with: registrar)
    }

    if let registrar = registry.registrar(forPlugin: "PrivateServerEventHandler") {
      PrivateServerEventHandler.register(with: registrar)
    }
  }

  /// Prepares the file system directories for use.
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
      appLogger.info("logs directory created at: \(FilePath.logsDirectory.path)")
    } catch {
      appLogger.error("Failed to create directory: \(error.localizedDescription)")
    }

    guard FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path) else {
      appLogger.error("Failed to change current directory to: \(FilePath.sharedDirectory.path)")
      return
    }
    appLogger.info("Current directory changed to: \(FilePath.sharedDirectory.path)")
  }

  /// Configures the Flutter local notifications plugin with the background isolate.
  ///
  /// Reference:
  /// https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/example/ios/Runner/AppDelegate.swift
  private func notificationSetup() {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
  }

  /// Calls API handler setup.
  private func setupRadiance() {
    appLogger.info("absoluteString Paths... \(FilePath.sharedDirectory.absoluteString)")
    appLogger.info("relativePath Paths... \(FilePath.sharedDirectory.relativePath)")
    Task {
      let baseDir = FilePath.sharedDirectory.relativePath
      let opts = UtilsOpts()
      opts.dataDir = baseDir
      opts.logDir = FilePath.logsDirectory.relativePath
      opts.deviceid = DeviceIdentifier.getUDID()
      opts.logLevel = "trace"
      opts.locale = Locale.current.identifier
      opts.telemetryConsent = FilePath.isTelemetryEnabled()
      opts.env = FilePath.isRadianceEnv()
      var error: NSError?
      MobileSetupRadiance(opts, FlutterEventListener.shared, &error)
      if let error {
        appLogger.error("Error while setting up radiance: \(error)")
      }
    }
  }
}
