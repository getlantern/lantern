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

    // Set up the file system on a background thread, then start the Go backend.
    // setupRadiance must not run until the file system (including migration) is ready.
    Task {
      do {
        try await setupFileSystem()
      } catch {
        appLogger.error("File system setup failed, aborting backend startup: \(error.localizedDescription)")
        return
      }
      setupRadiance()
    }

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
  /// Throws if directories cannot be created — callers must not proceed to setupRadiance on failure.
  /// Runs on a background thread to avoid blocking app launch.
  private func setupFileSystem() async throws {
    try await Task.detached(priority: .userInitiated) {
      let fm = FileManager.default
      // withIntermediateDirectories:true creates sharedDirectory implicitly.
      try fm.createDirectory(at: FilePath.logsDirectory, withIntermediateDirectories: true)
      appLogger.info("Logs directory: \(FilePath.logsDirectory.path)")
      try fm.createDirectory(at: FilePath.dataDirectory, withIntermediateDirectories: true)
      appLogger.info("Data directory: \(FilePath.dataDirectory.path)")
      self.migrateDataDirectory()
    }.value
  }

  /// Moves legacy data files from the App Group root into the data subdirectory.
  /// Checks whether any legacy file still exists at the root — if none do, migration is done.
  private func migrateDataDirectory() {
    let fm = FileManager.default
    let legacyFiles = [
      "local.json",
      "config.json",
      "servers.json",
      "wg.key",
      ".salt",
      "fronted_cache.json",
      "dnstt.yml.gz",
      "apps_cache.json",
      "url_test_history.json",
    ]
    guard legacyFiles.contains(where: { fm.fileExists(atPath: FilePath.sharedDirectory.appendingPathComponent($0).path) }) else {
      appLogger.info("Data directory migration: already migrated or new install, skipping")
      return
    }
    appLogger.info("Data directory migration: starting")

    for fileName in legacyFiles {
      let src = FilePath.sharedDirectory.appendingPathComponent(fileName)
      let dst = FilePath.dataDirectory.appendingPathComponent(fileName)
      guard fm.fileExists(atPath: src.path) else { continue }
      if fm.fileExists(atPath: dst.path) {
        // dst already exists — remove the legacy src so the sentinel can clear
        do {
          try fm.removeItem(at: src)
        } catch {
          appLogger.error("Data directory migration: failed to remove legacy \(fileName): \(error.localizedDescription)")
        }
        continue
      }
      do {
        try fm.moveItem(at: src, to: dst)
        appLogger.info("Migrated \(fileName) to data directory")
      } catch {
        appLogger.error("Failed to migrate \(fileName): \(error.localizedDescription)")
      }
    }
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
    Task {
      let baseDir = FilePath.dataDirectory.relativePath
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
