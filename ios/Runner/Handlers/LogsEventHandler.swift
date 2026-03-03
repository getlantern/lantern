import Flutter
import Foundation

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"
  private static let maxInitialLines = 800

  private var events: FlutterEventSink?
  private var channel: FlutterEventChannel?
  private var fileStreamer: IOSFileLogStreamer?

  deinit {
    fileStreamer?.stop()
    fileStreamer = nil
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

    fileStreamer?.stop()
    let fileStreamer = IOSFileLogStreamer(
      fileURL: Self.logFileURL,
      maxInitialLines: Self.maxInitialLines)
    self.fileStreamer = fileStreamer
    fileStreamer.start { [weak self] lines in
      self?.emit(lines)
    }

    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    fileStreamer?.stop()
    fileStreamer = nil
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
  
  private static let logFileURL = FilePath.logsDirectory.appendingPathComponent("lantern.log")
}

final class IOSFileLogStreamer {
  private static let maxReadBytes = 256 * 1024

  private let fileURL: URL
  private let maxInitialLines: Int
  private let pollInterval: DispatchTimeInterval
  private let queue = DispatchQueue(label: "org.getlantern.lantern.ios.file-log-streamer")
  private var timer: DispatchSourceTimer?
  private var offset: UInt64 = 0
  private var pendingPartialLine = ""
  private var onLines: (([String]) -> Void)?

  init(
    fileURL: URL,
    maxInitialLines: Int,
    pollInterval: DispatchTimeInterval = .milliseconds(700)
  ) {
    self.fileURL = fileURL
    self.maxInitialLines = maxInitialLines
    self.pollInterval = pollInterval
  }

  func start(_ onLines: @escaping ([String]) -> Void) {
    queue.sync {
      stopLocked()
      self.onLines = onLines
      emitInitialSnapshotLocked()

      let timer = DispatchSource.makeTimerSource(queue: queue)
      timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
      timer.setEventHandler { [weak self] in
        self?.pollLocked()
      }
      self.timer = timer
      timer.resume()
    }
  }

  func stop() {
    queue.sync {
      stopLocked()
    }
  }

  private func stopLocked() {
    timer?.setEventHandler {}
    timer?.cancel()
    timer = nil
    onLines = nil
    offset = 0
    pendingPartialLine = ""
  }

  private func emitInitialSnapshotLocked() {
    guard let onLines else {
      return
    }
    let lines = readLastLines(from: fileURL, maxLines: maxInitialLines)
    offset = fileSize(of: fileURL)
    if !lines.isEmpty {
      onLines(lines)
    }
  }

  private func pollLocked() {
    guard let onLines else {
      return
    }
    let lines = readNewLines()
    if !lines.isEmpty {
      onLines(lines)
    }
  }

  private func readLastLines(from url: URL, maxLines: Int) -> [String] {
    guard let handle = try? FileHandle(forReadingFrom: url) else {
      return []
    }
    defer { try? handle.close() }

    let fileSize = handle.seekToEndOfFile()
    let bytesToRead = min(fileSize, UInt64(Self.maxReadBytes))
    handle.seek(toFileOffset: fileSize - bytesToRead)
    let data = handle.readDataToEndOfFile()
    guard !data.isEmpty else {
      return []
    }

    var lines = parseLines(from: data)
    if bytesToRead < fileSize && !startsAtLineBoundary(data) && !lines.isEmpty {
      // Initial tail starts mid-file, so the first decoded entry can be a partial line.
      lines.removeFirst()
    }
    if lines.count > maxLines {
      lines = Array(lines.suffix(maxLines))
    }
    return lines
  }

  private func readNewLines() -> [String] {
    guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
      return []
    }
    defer { try? handle.close() }

    let fileSize = handle.seekToEndOfFile()
    if offset > fileSize {
      offset = 0
    }
    guard fileSize > offset else {
      return []
    }

    let unread = fileSize - offset
    let bytesToRead = min(unread, UInt64(Self.maxReadBytes))

    handle.seek(toFileOffset: offset)
    let data = handle.readData(ofLength: Int(bytesToRead))
    offset += UInt64(data.count)

    return parseChunkLines(from: data)
  }

  private func fileSize(of url: URL) -> UInt64 {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else {
      return 0
    }
    return (attrs[.size] as? NSNumber)?.uint64Value ?? 0
  }

  private func parseLines(from data: Data) -> [String] {
    guard let content = String(data: data, encoding: .utf8) else {
      return []
    }
    return content
      .split(whereSeparator: \.isNewline)
      .map(String.init)
      .filter { !$0.isEmpty }
  }

  private func parseChunkLines(from data: Data) -> [String] {
    guard !data.isEmpty, let content = String(data: data, encoding: .utf8) else {
      return []
    }

    let normalizedContent = content
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    let combined = pendingPartialLine + normalizedContent
    let endsWithNewline = combined.hasSuffix("\n")

    var pieces = combined.components(separatedBy: "\n")
    if !endsWithNewline {
      pendingPartialLine = pieces.popLast() ?? ""
    } else {
      pendingPartialLine = ""
    }

    return pieces.filter { !$0.isEmpty }
  }

  private func startsAtLineBoundary(_ data: Data) -> Bool {
    guard let first = data.first else {
      return true
    }
    return first == 0x0A || first == 0x0D
  }
}
