import FlutterMacOS
import Foundation

final class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var tailer: LogDirectoryTailer?

  deinit {
    tailer?.stop()
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    let inst = LogsEventHandler()
    inst.channel = FlutterEventChannel(name: Self.name, binaryMessenger: registrar.messenger)
    inst.channel?.setStreamHandler(inst)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    tailer?.stop()
    eventSink = events

    let tailer = LogDirectoryTailer(logDirectory: FilePath.logsDirectory) { [weak self] lines in
      guard !lines.isEmpty else { return }
      DispatchQueue.main.async {
        self?.eventSink?(lines)
      }
    }
    self.tailer = tailer
    tailer.start()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tailer?.stop()
    tailer = nil
    eventSink = nil
    return nil
  }
}

private final class LogDirectoryTailer {
  private struct FileState {
    var offset: UInt64
    var partialLine: String
  }

  private let logDirectory: URL
  private let onBatch: ([String]) -> Void
  private let queue = DispatchQueue(label: "org.getlantern.lantern.logs-tailer", qos: .utility)
  private let maxInitialBytes: UInt64 = 64 * 1024
  private let maxInitialLines = 500
  private var states: [URL: FileState] = [:]
  private var timer: DispatchSourceTimer?

  init(logDirectory: URL, onBatch: @escaping ([String]) -> Void) {
    self.logDirectory = logDirectory
    self.onBatch = onBatch
  }

  func start() {
    queue.async { [weak self] in
      guard let self else { return }
      self.emitInitialSnapshot()
      self.startTimer()
    }
  }

  func stop() {
    queue.async { [weak self] in
      self?.timer?.cancel()
      self?.timer = nil
      self?.states.removeAll()
    }
  }

  private func startTimer() {
    timer?.cancel()
    let timer = DispatchSource.makeTimerSource(queue: queue)
    timer.schedule(deadline: .now() + .seconds(1), repeating: .seconds(1))
    timer.setEventHandler { [weak self] in
      self?.poll()
    }
    self.timer = timer
    timer.resume()
  }

  private func emitInitialSnapshot() {
    var snapshot = [String]()
    for file in logFiles() {
      guard let size = fileSize(file) else { continue }
      states[file] = FileState(offset: size, partialLine: "")
      snapshot.append(contentsOf: tailLines(file, size: size))
    }

    if snapshot.count > maxInitialLines {
      snapshot = Array(snapshot.suffix(maxInitialLines))
    }
    onBatch(snapshot)
  }

  private func poll() {
    let files = logFiles()
    let liveFiles = Set(files)
    states = states.filter { liveFiles.contains($0.key) }

    var batch = [String]()
    for file in files {
      guard let size = fileSize(file) else { continue }
      var state = states[file] ?? FileState(offset: 0, partialLine: "")
      if size < state.offset {
        state = FileState(offset: 0, partialLine: "")
      }
      guard size > state.offset else {
        states[file] = state
        continue
      }
      batch.append(contentsOf: readLines(file, from: state.offset, state: &state))
      states[file] = state
    }

    onBatch(batch)
  }

  private func logFiles() -> [URL] {
    do {
      try FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
      return try FileManager.default.contentsOfDirectory(
        at: logDirectory,
        includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
      .filter { url in
        guard url.pathExtension == "log" else { return false }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile ?? false
      }
      .sorted { $0.path < $1.path }
    } catch {
      appLogger.error("Unable to enumerate log directory \(logDirectory.path): \(error)")
      return []
    }
  }

  private func fileSize(_ file: URL) -> UInt64? {
    guard let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
      return nil
    }
    return UInt64(size)
  }

  private func tailLines(_ file: URL, size: UInt64) -> [String] {
    var state = FileState(offset: size > maxInitialBytes ? size - maxInitialBytes : 0, partialLine: "")
    let skippedPrefix = state.offset > 0
    var lines = readLines(file, from: state.offset, state: &state)
    if skippedPrefix && !lines.isEmpty {
      lines.removeFirst()
    }
    if lines.count > maxInitialLines {
      lines = Array(lines.suffix(maxInitialLines))
    }
    return lines
  }

  private func readLines(_ file: URL, from offset: UInt64, state: inout FileState) -> [String] {
    do {
      let handle = try FileHandle(forReadingFrom: file)
      defer { try? handle.close() }
      handle.seek(toFileOffset: offset)
      let data = handle.readDataToEndOfFile()
      state.offset = handle.offsetInFile

      guard !data.isEmpty else { return [] }
      let chunk = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
      let text = state.partialLine + chunk
      let endsWithNewline = text.last.map { $0 == "\n" || $0 == "\r" } ?? false
      var parts = text.components(separatedBy: .newlines)

      if endsWithNewline {
        state.partialLine = ""
      } else {
        state.partialLine = parts.popLast() ?? ""
      }

      return parts
        .map { $0.trimmingCharacters(in: .newlines) }
        .filter { !$0.isEmpty }
    } catch {
      appLogger.error("Unable to read log file \(file.path): \(error)")
      return []
    }
  }
}
