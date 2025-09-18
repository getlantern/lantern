import Combine
import FlutterMacOS
import Liblantern

final class LogsEventHandler: NSObject, MobileLogSinkProtocol, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let inst = LogsEventHandler()
    inst.channel = FlutterEventChannel(name: Self.name, binaryMessenger: registrar.messenger)
    inst.channel?.setStreamHandler(inst)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    self.eventSink = events

    let dataDir = FilePath.dataDirectory.path
    let logFile = FilePath.logsDirectory.appendingPathComponent("lantern.log").path

    var err: NSError?
    MobileStartLogs(self, dataDir, logFile, 500, &err)
    if let err {
      return FlutterError(
        code: "LOGS_START_FAILED", message: err.localizedDescription, details: nil)
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    MobileStopLogs()
    self.eventSink = nil
    return nil
  }

  // LogSink (callback from Go)
  func writeLogs(_ p0: String?) {
    guard let sink = self.eventSink, let batch = p0, !batch.isEmpty else { return }
    let lines = batch.split(whereSeparator: \.isNewline).map(String.init)
    DispatchQueue.main.async {
      sink(lines)
    }
  }
}
