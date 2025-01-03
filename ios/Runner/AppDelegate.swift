import Flutter
import UIKit
import NetworkExtension

enum VPNManagerError: Swift.Error {
  case userDisallowedVPNConfigurations
  case loadingProviderFailed
  case savingProviderFailed
  case unknown
}

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var vpnManager = NETunnelProviderManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let nativeChannel = FlutterMethodChannel(name: "org.getlantern.lantern/native",
                                             binaryMessenger: controller.binaryMessenger)
    
    nativeChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      
      // Handle method calls from Dart
      switch call.method {
      case "startVPN":
        self.startVPN(result: result)
      case "stopVPN":
        self.stopVPN(result: result)
      case "isVPNConnected":
        self.isVPNConnected(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startVPN(result: @escaping FlutterResult) {
   loadVPNPreferences { success in
      if success {
        do {
          let options = ["netEx.StartReason": NSString("User Initiated")]
          
          print("Starting tunnel..")
          try self.vpnManager.connection.startVPNTunnel(options: options)

          print("Tunnel started successfully")
          result("VPN Started")
        } catch {
          result(FlutterError(code: "START_FAILED", message: "Unable to start VPN tunnel", details: nil))
        }
      } else {
        result(FlutterError(code: "CONFIG_FAILED", message: "VPN configuration failed", details: nil))
      }
    }
  }
  
  private func stopVPN(result: @escaping FlutterResult) {
    print("Stopping tunnel..")
    vpnManager.connection.stopVPNTunnel()
    let success =  true
    if success {
      result("VPN Stopped Successfully")
    } else {
      result(FlutterError(code: "VPN_STOP_FAILED",
                          message: "Failed to stop VPN",
                          details: nil))
    }
  }

   private func loadVPNPreferences(completion: @escaping (Bool) -> Void) {
      NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
          if let error = error {
              print("Error loading VPN preferences: \(error)")
              completion(false)
              return
          }
          
          if let manager = managers?.first {
              self.vpnManager = manager
              completion(true)
          } else {
              self.setupVPN(completion: completion)
          }
      }
    }
    

  private func setupVPN(completion: @escaping (Bool) -> Void) {
    let tunnelProtocol = NETunnelProviderProtocol()
    tunnelProtocol.providerBundleIdentifier = "org.getlantern.lantern.Tunnel"
    tunnelProtocol.serverAddress = "0.0.0.0"
    
    vpnManager.protocolConfiguration = tunnelProtocol
    vpnManager.localizedDescription = "Lantern"
    vpnManager.isEnabled = true
      
    let alwaysConnectRule = NEOnDemandRuleConnect()
    vpnManager.onDemandRules = [alwaysConnectRule]
    vpnManager.isOnDemandEnabled = true

    vpnManager.saveToPreferences { [weak self] error in
        if let error = error {
            print("Error saving VPN preferences: \(error)")
            completion(false)
        } else {
            self?.vpnManager.loadFromPreferences { error in
                if let error = error {
                    print("Error loading VPN preferences: \(error)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
  }
  
  private func isVPNConnected(result: FlutterResult) {
    let isConnected = 1
    result(isConnected)
  }
}
