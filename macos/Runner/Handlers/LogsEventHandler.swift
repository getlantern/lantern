import Combine
import FlutterMacOS


final class LogsEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
  static let name = "org.getlantern.lantern/logs"

  private var channel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?
  private var tailer: LogTailer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let inst = LogsEventHandler()
    inst.channel = FlutterEventChannel(name: Self.name, binaryMessenger: registrar.messenger)
    inst.channel?.setStreamHandler(inst)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events

    try? FileManager.default.createDirectory(at: FilePath.logsDirectory, withIntermediateDirectories: true)

    let logFile = FilePath.logsDirectory.appendingPathComponent("lantern.log")

    if let last = try? LogTailer.readLastLines(path: logFile.path, maxLines: 200) {
      events(last)
    }

    tailer = LogTailer(path: logFile.path) { [weak self] newLines in
      self?.eventSink?(newLines)
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    tailer?.stop()
    tailer = nil
    eventSink = nil
    return nil
  }
}

final class LogTailer {
    private let path: String
    private var fd: Int32 = -1
    private var src: DispatchSourceFileSystemObject?
    private var handle: FileHandle?
    private var offset: UInt64 = 0
    private let onLines: ([String]) -> Void

    init?(path: String, onLines: @escaping ([String]) -> Void) {
        self.path = path
        self.onLines = onLines

        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        guard let h = FileHandle(forReadingAtPath: path) else { return nil }
        handle = h

        fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }

        if let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size]) as? UInt64 {
            offset = size
            try? handle?.seek(toOffset: offset)
        }

        let q = DispatchQueue.global(qos: .utility)
        let s = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete], queue: q)
        s.setEventHandler { [weak self] in self?.handleEvent() }
        s.setCancelHandler { [weak self] in if let fd = self?.fd, fd >= 0 { close(fd) } }
        s.resume()
        src = s
    }

    func stop() {
        src?.cancel()
        src = nil
        try? handle?.close()
    }

    private func handleEvent() {
        guard let src = src else { return }
        let ev = src.data

        if ev.contains(.rename) || ev.contains(.delete) {
            src.suspend()
            try? handle?.close()
            handle = FileHandle(forReadingAtPath: path)
            offset = 0
            try? handle?.seek(toOffset: offset)
            src.resume()
            return
        }

        do {
            try handle?.seek(toOffset: offset)
            let data = try handle?.readToEnd() ?? Data()
            guard !data.isEmpty else { return }
            offset += UInt64(data.count)
            let text = String(decoding: data, as: UTF8.self)
            let lines = text.split(whereSeparator: \.isNewline).map(String.init)
            if !lines.isEmpty { onLines(lines) }
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
