import Combine
import Flutter
import Foundation

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"
  private static let reconnectInterval: DispatchTimeInterval = .seconds(5)
  private static let logMaxLines = 1200

  private var events: FlutterEventSink?
  private var channel: FlutterEventChannel?
  private var logClient: CommandClient?
  private var logObserver: AnyCancellable?
  private var reconnectTimer: DispatchSourceTimer?
  private var batchDiffer = LogBatchDiffer()

  deinit {
    tearDownStream()
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
    startStreaming()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tearDownStream()
    events = nil
    return nil
  }

  private func startStreaming() {
    tearDownStream()
    batchDiffer.reset()

    let client = CommandClient(.log, logMaxLines: Self.logMaxLines)
    logClient = client
    logObserver = client.$logList.sink { [weak self] logs in
      self?.emitDiff(logs)
    }

    client.connect()
    startReconnectLoop()
  }

  private func startReconnectLoop() {
    reconnectTimer?.setEventHandler {}
    reconnectTimer?.cancel()

    let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
    timer.schedule(
      deadline: .now() + Self.reconnectInterval,
      repeating: Self.reconnectInterval)
    timer.setEventHandler { [weak self] in
      self?.reconnectIfNeeded()
    }
    reconnectTimer = timer
    timer.resume()
  }

  private func reconnectIfNeeded() {
    guard events != nil else {
      return
    }
    guard let logClient else {
      startStreaming()
      return
    }
    if !logClient.isConnected {
      logClient.connect()
    }
  }

  private func tearDownStream() {
    reconnectTimer?.setEventHandler {}
    reconnectTimer?.cancel()
    reconnectTimer = nil

    logObserver?.cancel()
    logObserver = nil

    logClient?.disconnect()
    logClient = nil
  }

  private func emitDiff(_ logs: [String]) {
    let batch = batchDiffer.consume(logs)
    guard !batch.isEmpty else {
      return
    }
    DispatchQueue.main.async { [weak self] in
      guard let sink = self?.events else {
        return
      }
      sink(batch)
    }
  }
}

struct LogBatchDiffer {
  private var previous: [String] = []

  mutating func reset() {
    previous = []
  }

  mutating func consume(_ current: [String]) -> [String] {
    defer {
      previous = current
    }

    guard !current.isEmpty else {
      return []
    }
    guard !previous.isEmpty else {
      return current
    }

    let maxOverlap = min(previous.count, current.count)
    for overlap in stride(from: maxOverlap, through: 1, by: -1) {
      if previous.suffix(overlap).elementsEqual(current.prefix(overlap)) {
        return Array(current.dropFirst(overlap))
      }
    }
    return current
  }
}
