import Cocoa
import Combine
import FlutterMacOS
import IOKit.ps

class MainFlutterWindow: NSWindow {

  private var cancellable: AnyCancellable?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    let nativeChannel = FlutterMethodChannel(
      name: "org.getlantern.lantern/method",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let methodHandler = MethodHandler(channel: nativeChannel, vpnManager: VPNManager.shared)

    let registrar = flutterViewController.registrar(forPlugin: "StatusEventHandler")
    let statusChannel = FlutterEventChannel(
      name: "org.getlantern.lantern/status",
      binaryMessenger: registrar.messenger, codec: FlutterJSONMethodCodec())
    statusChannel.setStreamHandler(self)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}

extension MainFlutterWindow: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    cancellable = VPNManager.shared.$connectionStatus.sink { [events] status in
      switch status {
      case .reasserting, .connecting:
        events(["status": "Connecting"])
      case .connected:
        events(["status": "Connected"])
      case .disconnecting:
        events(["status": "Disconnecting"])
      case .disconnected, .invalid:
        events(["status": "Disconnected"])
      @unknown default:
        events(["status": "Disconnected"])
      }
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    //cancellable?.cancel()
    return nil
  }
}
