import Flutter
import UIKit
import NetworkExtension

@main
@objc class AppDelegate: FlutterAppDelegate {

    private var vpnManager = VPNManager.shared
    
    private var methodHandler: MethodHandler?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }

        // Initialize the Flutter method channel
        let nativeChannel = FlutterMethodChannel(name: "org.getlantern.lantern/native",
                                                 binaryMessenger: controller.binaryMessenger)

        // Initialize and assign the MethodHandler to handle method calls
        methodHandler = MethodHandler(channel: nativeChannel, vpnManager: vpnManager)

        GeneratedPluginRegistrant.register(with: self)

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
