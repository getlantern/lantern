import Flutter
import Liblantern
import NetworkExtension
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var vpnManager = VPNManager.shared

  private var methodHandler: MethodHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }

    GeneratedPluginRegistrant.register(with: self)

    if let registrar = self.registrar(forPlugin: "StatusEventHandler") {
      StatusEventHandler.register(with: registrar)
    }

    if let registrar = self.registrar(forPlugin: "LogsEventHandler") {
      LogsEventHandler.register(with: registrar)
    }

    setupMethodHandler(controller: controller)
    setupFileManager()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func setupMethodHandler(controller: FlutterViewController) {
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: controller.binaryMessenger)
    methodHandler = MethodHandler(channel: nativeChannel, vpnManager: vpnManager)

  }

  private func setupFileManager() {
    do {
      try FileManager.default.createDirectory(
        at: FilePath.workingDirectory, withIntermediateDirectories: true)
    } catch {
      print("Failed to create working directory: \(error.localizedDescription)")
    }

    guard FileManager.default.changeCurrentDirectoryPath(FilePath.sharedDirectory.path) else {
      print("Failed to change current directory to: \(FilePath.sharedDirectory.path)")
    }
  }
}
