import Foundation

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var events: FlutterEventSink?
  private var channel: FlutterEventChannel?
  private let streamQueue = DispatchQueue(label: "org.getlantern.lantern.logs.stream")
  private let pollInterval: DispatchTimeInterval = .seconds(1)
  private var pollTimer: DispatchSourceTimer?
  private var streamer: IOSDiagnosticLogStreamer?

  deinit {
    streamQueue.sync {
      stopPollingLocked()
      streamer = nil
    }
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
    let streamer = IOSDiagnosticLogStreamer(logsDirectory: FilePath.logsDirectory)
    streamQueue.async { [weak self] in
      guard let self else {
        return
      }
      self.streamer = streamer
      self.startPollingLocked()
      self.emit(streamer.initialSnapshot())
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    streamQueue.async { [weak self] in
      guard let self else {
        return
      }
      self.stopPollingLocked()
      self.streamer = nil
    }
    events = nil
    return nil
  }

  private func startPollingLocked() {
    stopPollingLocked()

    let timer = DispatchSource.makeTimerSource(queue: streamQueue)
    timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
    timer.setEventHandler { [weak self] in
      guard
        let self,
        let streamer = self.streamer
      else {
        return
      }
      self.emit(streamer.readUpdates())
    }
    pollTimer = timer
    timer.resume()
  }

  private func stopPollingLocked() {
    pollTimer?.setEventHandler {}
    pollTimer?.cancel()
    pollTimer = nil
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

private final class IOSDiagnosticLogStreamer {
  private static let appLogFile = "lantern.log"
  private static let iosLogFile = "lantern_ios.log"
  private static let initialLinesPerFile = 200
  private static let maxLinesPerUpdate = 400

  private let tailers: [IncrementalFileTailer]

  init(logsDirectory: URL) {
    tailers = [
      IncrementalFileTailer(fileURL: logsDirectory.appendingPathComponent(Self.appLogFile)),
      IncrementalFileTailer(fileURL: logsDirectory.appendingPathComponent(Self.iosLogFile)),
    ]
  }

  func initialSnapshot() -> [String] {
    var lines: [String] = []
    for tailer in tailers {
      lines.append(contentsOf: tailer.initializeFromTail(maxLines: Self.initialLinesPerFile))
    }
    return lines
  }

  func readUpdates() -> [String] {
    var lines: [String] = []
    for tailer in tailers {
      lines.append(contentsOf: tailer.readNewLines())
    }
    if lines.count > Self.maxLinesPerUpdate {
      return Array(lines.suffix(Self.maxLinesPerUpdate))
    }
    return lines
  }
}

private final class IncrementalFileTailer {
  private static let initialReadLimitBytes = 256 * 1024

  private let fileURL: URL
  private var offset: UInt64 = 0
  private var partialLine = ""

  init(fileURL: URL) {
    self.fileURL = fileURL
  }

  func initializeFromTail(maxLines: Int) -> [String] {
    partialLine = ""

    guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
      offset = 0
      return []
    }
    defer {
      try? handle.close()
    }

    do {
      let fileSize = try handle.seekToEnd()
      if fileSize == 0 {
        offset = 0
        return []
      }

      let limit = UInt64(Self.initialReadLimitBytes)
      let startOffset = fileSize > limit ? fileSize - limit : 0
      try handle.seek(toOffset: startOffset)

      let data = handle.readDataToEndOfFile()
      offset = startOffset + UInt64(data.count)
      var lines = Self.extractLines(from: data, carryingPartialLineIn: &partialLine)

      // If we sought into the middle of the file, drop the first potentially partial line.
      if startOffset > 0, !lines.isEmpty {
        lines.removeFirst()
      }

      if lines.count > maxLines {
        lines = Array(lines.suffix(maxLines))
      }
      return lines
    } catch {
      offset = 0
      return []
    }
  }

  func readNewLines() -> [String] {
    guard
      let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
      let sizeNumber = attrs[.size] as? NSNumber
    else {
      offset = 0
      partialLine = ""
      return []
    }

    let fileSize = sizeNumber.uint64Value
    if fileSize < offset {
      // File was rotated or truncated.
      offset = 0
      partialLine = ""
    }

    guard fileSize > offset else {
      return []
    }

    guard let handle = try? FileHandle(forReadingFrom: fileURL) else {
      return []
    }
    defer {
      try? handle.close()
    }

    do {
      try handle.seek(toOffset: offset)
      let data = handle.readDataToEndOfFile()
      offset += UInt64(data.count)

      guard !data.isEmpty else {
        return []
      }
      return Self.extractLines(from: data, carryingPartialLineIn: &partialLine)
    } catch {
      return []
    }
  }

  private static func extractLines(from data: Data, carryingPartialLineIn partial: inout String)
    -> [String]
  {
    guard !data.isEmpty else {
      return []
    }

    let chunk = String(decoding: data, as: UTF8.self)
    let combined = partial + chunk
    let normalized = combined
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")

    let hasTrailingNewline = normalized.hasSuffix("\n")
    var parts = normalized
      .split(separator: "\n", omittingEmptySubsequences: false)
      .map(String.init)

    if hasTrailingNewline {
      partial = ""
    } else {
      partial = parts.popLast() ?? ""
    }

    parts.removeAll(where: \.isEmpty)
    return parts
  }
}
