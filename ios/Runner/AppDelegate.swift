import Flutter
import Liblantern
import NetworkExtension
import UIKit
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let vpnManager = VPNManager.shared
  private var methodHandler: MethodHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {

    // Ensure root controller is a FlutterViewController
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not a FlutterViewController")
    }

    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)

    // Configure Flutter local notifications
    notificationSetup()

    // Register event handlers
    registerEventHandlers()

    // Setup native method channel
    setupMethodHandler(controller: controller)

    // Initialize directories and working paths
    setupFileSystem()

    // set radiance
    setupRadiance()
    NSSetUncaughtExceptionHandler { exception in
      print(exception.reason)
      print(exception.callStackSymbols)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Registers Flutter event channel handlers
  private func registerEventHandlers() {
    if let registrar = self.registrar(forPlugin: "StatusEventHandler") {
      StatusEventHandler.register(with: registrar)
    }

    if let registrar = self.registrar(forPlugin: "LogsEventHandler") {
      LogsEventHandler.register(with: registrar)
    }

    if let registrar = self.registrar(forPlugin: "PrivateServerEventHandler") {
      PrivateServerEventHandler.register(with: registrar)
    }
  }

  /// Initializes the native method channel handler
  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.binaryMessenger
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

  /// Configures the Flutter local notifications plugin with the background isolate
  ///
  /// Reference:
  /// https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/example/ios/Runner/AppDelegate.swift
  private func notificationSetup() {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }

    // Set UNUserNotificationCenter delegate to handle foreground notifications
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
  }

  /// Calls API handler setup
  private func setupRadiance() {
    Task {
      // Set up the base directory and options
      let baseDir = FilePath.workingDirectory.relativePath
      let opts = MobileOpts()
      opts.dataDir = baseDir
      opts.deviceid = DeviceIdentifier.getUDID()
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
