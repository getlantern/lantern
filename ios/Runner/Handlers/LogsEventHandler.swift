import Flutter
import Foundation

class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var tailer: LogTailer?

  deinit {
    tailer?.stop()
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
    eventSink = events

    try? FileManager.default.createDirectory(
      at: FilePath.logsDirectory, withIntermediateDirectories: true)

    let logFile = FilePath.logsDirectory.appendingPathComponent("lantern.log")
    if let last = try? LogTailer.readLastLines(path: logFile.path, maxLines: 200), !last.isEmpty {
      events(last)
    }

    tailer = LogTailer(path: logFile.path) { [weak self] newLines in
      self?.eventSink?(newLines)
    }
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tailer?.stop()
    tailer = nil
    eventSink = nil
    return nil
  }
}

final class LogTailer {
  private let path: String
  private var fd: Int32 = -1
  private var source: DispatchSourceFileSystemObject?
  private var handle: FileHandle?
  private var offset: UInt64 = 0
  private let onLines: ([String]) -> Void

  init?(path: String, onLines: @escaping ([String]) -> Void) {
    self.path = path
    self.onLines = onLines

    if !FileManager.default.fileExists(atPath: path) {
      FileManager.default.createFile(atPath: path, contents: nil)
    }
    handle = FileHandle(forReadingAtPath: path)

    fd = open(path, O_RDONLY)
    guard fd >= 0 else { return nil }

    if let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? UInt64 {
      offset = size
      try? handle?.seek(toOffset: offset)
    }

    let queue = DispatchQueue.global(qos: .utility)
    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete], queue: queue)
    source.setEventHandler { [weak self] in self?.handleEvent() }
    source.setCancelHandler { [weak self] in
      if let fd = self?.fd, fd >= 0 {
        close(fd)
      }
    }
    source.resume()
    self.source = source
  }

  func stop() {
    source?.cancel()
    source = nil
    try? handle?.close()
    handle = nil
  }

  private func reopenHandleIfNeeded(resetOffset: Bool) {
    if !FileManager.default.fileExists(atPath: path) {
      FileManager.default.createFile(atPath: path, contents: nil)
    }
    if handle == nil {
      handle = FileHandle(forReadingAtPath: path)
    }
    if resetOffset {
      offset = 0
    }
    try? handle?.seek(toOffset: offset)
  }

  private func handleEvent() {
    guard let source = source else { return }
    let event = source.data

    if event.contains(.rename) || event.contains(.delete) {
      source.suspend()
      try? handle?.close()
      handle = nil
      reopenHandleIfNeeded(resetOffset: true)
      source.resume()
      return
    }

    do {
      if handle == nil {
        reopenHandleIfNeeded(resetOffset: false)
      }
      guard let handle else { return }

      try handle.seek(toOffset: offset)
      let data = try handle.readToEnd() ?? Data()
      guard !data.isEmpty else { return }
      offset += UInt64(data.count)

      let lines = String(decoding: data, as: UTF8.self)
        .split(whereSeparator: \.isNewline)
        .map(String.init)
      if !lines.isEmpty {
        onLines(lines)
      }
    } catch {
    }
  }

  static func readLastLines(path: String, maxLines: Int) throws -> [String] {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let tail = data.suffix(64 * 1024)
    let lines = String(decoding: tail, as: UTF8.self)
      .split(whereSeparator: \.isNewline)
      .map(String.init)
    return Array(lines.suffix(maxLines))
  }
}
