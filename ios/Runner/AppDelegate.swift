import Flutter
import Liblantern
import NetworkExtension
import UIKit

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

    // Register event handlers
    registerEventHandlers()

    // Setup native method channel
    setupMethodHandler(controller: controller)

    // Initialize directories and working paths
    setupFileSystem()

    // Trigger VPN extension method for Radiance setup
    setupAPIHandler()

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

  /// Calls VPN extension method to set up Radiance
  private func setupAPIHandler() {
    Task {
      // Set up the base directory and options
      let baseDir = FilePath.workingDirectory.relativePath
      var opts = MobileOpts()
      opts.dataDir = baseDir
      opts.deviceid = DeviceIdentifier.getUDID()
      opts.locale = Locale.current.identifier
      var error: NSError?
      await MobileNewAPIHandler(opts, &error)
      // Handle any error returned by the setup
      if let error {
        appLogger.error("Error while setting up radiance: \(error)")
      }
    }
  }

}
