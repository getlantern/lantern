import Flutter
import Foundation
import Liblantern

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var subscription: MobileLogSubscription?
  private var listener: LogEntryListener?

  deinit {
    subscription?.cancel()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = LogsEventHandler()
    instance.channel = FlutterEventChannel(
      name: Self.name,
      binaryMessenger: registrar.messenger())
    instance.channel?.setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    subscription?.cancel()
    subscription = nil
    eventSink = events

    let listener = LogEntryListener { [weak self] entry in
      let trimmed = entry.trimmingCharacters(in: .newlines)
      guard !trimmed.isEmpty else { return }
      DispatchQueue.main.async {
        self?.eventSink?([trimmed])
      }
    }
    self.listener = listener

    var error: NSError?
    subscription = MobileTailLogs(listener, &error)
    if let error = error {
      self.listener = nil
      return FlutterError(
        code: "tail_logs_failed",
        message: error.localizedDescription,
        details: nil)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    subscription?.cancel()
    subscription = nil
    listener = nil
    eventSink = nil
    return nil
  }
}

private class LogEntryListener: NSObject, UtilsLogListenerProtocol {
  private let onEntry: (String) -> Void

  init(onEntry: @escaping (String) -> Void) {
    self.onEntry = onEntry
  }

    func onLogEntry(_ entry: String?) {
        onEntry(entry ?? "")
  }
}
