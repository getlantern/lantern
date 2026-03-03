import Combine
import Flutter
import Foundation

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"
  private static let maxBufferedLines = 4000

  private var events: FlutterEventSink?
  private var channel: FlutterEventChannel?
  private var streamer: IOSCommandLogStreamer?

  deinit {
    streamer?.stop()
    streamer = nil
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
    self.events = events
    streamer?.stop()
    let streamer = IOSCommandLogStreamer(
      client: CommandClientLogAdapter(logMaxLines: Self.maxBufferedLines))
    self.streamer = streamer
    streamer.start { [weak self] lines in
      self?.emit(lines)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamer?.stop()
    streamer = nil
    events = nil
    return nil
  }

  private func emit(_ lines: [String]) {
    guard !lines.isEmpty else {
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let sink = self?.events else {
        return
      }
      sink(lines)
    }
  }
}

protocol IOSCommandLogClient {
  var logsPublisher: AnyPublisher<[String], Never> { get }
  func connect()
  func disconnect()
}

final class CommandClientLogAdapter: IOSCommandLogClient {
  private let client: CommandClient

  init(logMaxLines: Int) {
    client = CommandClient(.log, logMaxLines: logMaxLines)
  }

  var logsPublisher: AnyPublisher<[String], Never> {
    client.$logList.eraseToAnyPublisher()
  }

  func connect() {
    client.connect()
  }

  func disconnect() {
    client.disconnect()
  }
}

final class IOSCommandLogStreamer {
  private let client: IOSCommandLogClient
  private var cancellable: AnyCancellable?
  private var previousSnapshot: [String] = []

  init(client: IOSCommandLogClient) {
    self.client = client
  }

  func start(_ onLines: @escaping ([String]) -> Void) {
    stop()
    cancellable = client.logsPublisher.sink { [weak self] snapshot in
      guard let self else {
        return
      }
      let delta = Self.deltaLines(previous: self.previousSnapshot, current: snapshot)
      self.previousSnapshot = snapshot
      if !delta.isEmpty {
        onLines(delta)
      }
    }
    client.connect()
  }

  func stop() {
    cancellable?.cancel()
    cancellable = nil
    previousSnapshot = []
    client.disconnect()
  }

  static func deltaLines(previous: [String], current: [String]) -> [String] {
    if current.isEmpty {
      return []
    }
    if previous.isEmpty {
      return current
    }
    if current.count >= previous.count && current.prefix(previous.count).elementsEqual(previous) {
      return Array(current.dropFirst(previous.count))
    }

    let maxOverlap = min(previous.count, current.count)
    if maxOverlap > 0 {
      for overlap in stride(from: maxOverlap, through: 1, by: -1) {
        if previous.suffix(overlap).elementsEqual(current.prefix(overlap)) {
          return Array(current.dropFirst(overlap))
        }
      }
    }
    return current
  }
}
