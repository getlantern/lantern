//
//  Logger.swift
//  Runner
//
//  Created by jigar fumakiya on 20/07/23.
//

import Foundation
import os
import zlib

let appLogger = LanternLogger()

/// Writes to `lantern_macos.log` in the shared logs directory. The tunnel extension
/// appends to the same file, so writes open/append/close instead of holding a
/// handle, and only the app process rotates.
///
/// Rotation matches FileLogPrinter (logger_service.dart) and radiance: 5 MB
/// live file, two gzipped `<name>-<stamp>.log.gz` backups. The name matters:
/// the issue-report archiver globs `*.log` and reads every match in full.
class LanternLogger {
  private let queue = DispatchQueue(label: "LanternLoggerQueue", qos: .utility)
  private let logFileURL: URL
  private let logger = OSLog(
    subsystem: Bundle.main.bundleIdentifier ?? "org.getlantern.lantern",
    category: "Lantern"
  )
  private let formatter = DateFormatter()
  private let utcTimeZone = TimeZone(identifier: "UTC")

  private static let maxFileBytes: UInt64 = 5 * 1024 * 1024
  private static let maxBackups = 2
  private static let checkIntervalBytes = 256 * 1024
  private static let backupExt = ".log.gz"

  /// Both the app and the tunnel extension rotate. Restricting it to the app
  /// left the file unbounded whenever the extension was the only live writer,
  /// which is the normal state during background VPN operation. Concurrent
  /// rotation is safe because the size check and the truncate both happen under
  /// the cross-process lock -- see rotateIfNeeded.
  /// Bytes appended since the last size check, so we don't stat on every line.
  private var sinceCheck = 0

  init() {
    let logsDir = FilePath.logsDirectory
    if !FileManager.default.fileExists(atPath: logsDir.path) {
      try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }
    self.logFileURL = logsDir.appendingPathComponent("lantern_macos.log")
    if !FileManager.default.fileExists(atPath: logFileURL.path) {
      FileManager.default.createFile(
        atPath: logFileURL.path, contents: nil, attributes: nil)
    }
    queue.async { [weak self] in self?.rotateIfNeeded() }
  }

  private func writeToFile(_ message: String, level: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let timestamp = formatTimestamp(Date())
      let formatted = "time=\"\(timestamp)\" level \(level) \(message)\n"
      guard let data = formatted.data(using: .utf8) else { return }
      if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
        // Exclusive lock so an append never lands mid-rotation in the other process.
        flock(fileHandle.fileDescriptor, LOCK_EX)
        do {
          try Self.appendAll(fileHandle.fileDescriptor, data)
        } catch {
          os_log("Log write failure: %{public}@", log: logger, type: .error,
               error.localizedDescription)
        }
        try? fileHandle.close()  // releases the lock
      }
      sinceCheck += data.count
      if sinceCheck >= Self.checkIntervalBytes {
        sinceCheck = 0
        rotateIfNeeded()
      }
    }
  }

  // MARK: - Rotation (runs on `queue`)

  private func rotateIfNeeded() {
    guard currentSize() >= Self.maxFileBytes else { return }
    // Hold the lock from snapshot through truncate so no append from the
    // extension can slip in between and be lost.
    guard let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
    flock(handle.fileDescriptor, LOCK_EX)
    // Recheck now that the lock is held: the other process may have rotated
    // while we waited, and rotating again would archive a nearly empty file and
    // discard the backup it just wrote.
    guard currentSize() >= Self.maxFileBytes else {
      try? handle.close()
      return
    }
    do {
      try compressToBackup()
    } catch {
      os_log("Log rotation failure: %{public}@", log: logger, type: .error,
             error.localizedDescription)
    }
    // Truncate in place (not rename) so the extension keeps writing to the same
    // file. Done even if compression failed (e.g. disk full), so the live file
    // stays bounded.
    // ftruncate rather than FileHandle: truncateFile raises an ObjC exception
    // and truncate(atOffset:) is 10.15.4+. This is the recovery path for a
    // failed compression, so it must not be the thing that aborts.
    if ftruncate(handle.fileDescriptor, 0) != 0 {
      os_log("Log truncate failure: errno %{public}d", log: logger, type: .error, errno)
    }
    try? handle.close()
    pruneBackups()
  }

  private var logName: String { logFileURL.deletingPathExtension().lastPathComponent }

  /// Matches the Go/Dart backup stamp: 2026-08-25T19-30-00.000
  private func backupStamp() -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = utcTimeZone
    f.dateFormat = "yyyy-MM-dd'T'HH-mm-ss.SSS"
    return f.string(from: Date())
  }

  /// Streams the live file into `<name>-<stamp>.log.gz` without loading it whole.
  private func compressToBackup() throws {
    let backup = logFileURL.deletingLastPathComponent()
      .appendingPathComponent("\(logName)-\(backupStamp())\(Self.backupExt)")
    do {
      try compress(logFileURL, to: backup)
    } catch {
      try? FileManager.default.removeItem(at: backup)
      throw error
    }
  }

  private func compress(_ source: URL, to backup: URL) throws {
    let input = try FileHandle(forReadingFrom: source)
    defer { try? input.close() }
    FileManager.default.createFile(atPath: backup.path, contents: nil)
    let output = try FileHandle(forWritingTo: backup)
    defer { try? output.close() }

    var stream = z_stream()
    // windowBits 15 + 16 selects the gzip container, matching lumberjack's output.
    guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15 + 16, 8,
                        Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK
    else { throw LogRotationError.deflateInit }
    defer { deflateEnd(&stream) }

    let chunk = 64 * 1024
    var outBuf = [UInt8](repeating: 0, count: chunk)
    var finished = false
    while !finished {
      var inBuf = try Self.readChunk(input.fileDescriptor, max: chunk)
      finished = inBuf.isEmpty
      let flush = finished ? Z_FINISH : Z_NO_FLUSH
      try inBuf.withUnsafeMutableBufferPointer { inPtr in
        stream.next_in = inPtr.baseAddress
        stream.avail_in = UInt32(inPtr.count)
        var rc = Z_OK
        repeat {
          try outBuf.withUnsafeMutableBufferPointer { outPtr in
            stream.next_out = outPtr.baseAddress
            stream.avail_out = UInt32(chunk)
            rc = deflate(&stream, flush)
            guard rc == Z_OK || rc == Z_STREAM_END || rc == Z_BUF_ERROR else {
              throw LogRotationError.deflate(rc)
            }
            let produced = chunk - Int(stream.avail_out)
            if produced > 0 {
              try Self.appendAll(output.fileDescriptor,
                                 Data(bytes: outPtr.baseAddress!, count: produced))
            }
          }
          // Z_FINISH must be repeated until Z_STREAM_END, not just until the
          // buffer fills, or the gzip trailer may never be written.
        } while stream.avail_out == 0 || (finished && rc != Z_STREAM_END)
      }
    }
  }

  private func pruneBackups() {
    let dir = logFileURL.deletingLastPathComponent()
    let prefix = "\(logName)-"
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
    // Stamps are fixed-width and zero-padded, so lexical order is chronological.
    let backups = names.filter { $0.hasPrefix(prefix) && $0.hasSuffix(Self.backupExt) }.sorted()
    for stale in backups.dropLast(Self.maxBackups) {
      try? FileManager.default.removeItem(at: dir.appendingPathComponent(stale))
    }
  }

  private enum LogRotationError: Error {
    case deflateInit
    case deflate(Int32)
    case io(Int32)
  }

  // POSIX rather than FileHandle.write(contentsOf:)/read(upToCount:). Those are
  // the throwing replacements, but they are macOS 10.15.4+ and this target
  // deploys to 10.15, so they would need an availability ladder whose fallback
  // is the very API being replaced. The legacy FileHandle.write/readData raise
  // NSFileHandleOperationException, which Swift cannot catch -- a full disk
  // aborts the process instead of reaching the recovery path that truncates the
  // live log. write(2)/read(2) report failure as a value on every OS we ship.

  /// Writes all of `data`, tolerating short writes and EINTR.
  private static func appendAll(_ fd: Int32, _ data: Data) throws {
    guard !data.isEmpty else { return }
    try data.withUnsafeBytes { raw in
      var written = 0
      while written < raw.count {
        let result = Darwin.write(fd, raw.baseAddress!.advanced(by: written),
                                  raw.count - written)
        if result < 0 {
          if errno == EINTR { continue }
          throw LogRotationError.io(errno)
        }
        written += result
      }
    }
  }

  /// Reads up to `max` bytes. An empty result means end of file.
  private static func readChunk(_ fd: Int32, max: Int) throws -> [UInt8] {
    var buf = [UInt8](repeating: 0, count: max)
    while true {
      let result = buf.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress, max) }
      if result < 0 {
        if errno == EINTR { continue }
        throw LogRotationError.io(errno)
      }
      buf.removeLast(max - result)
      return buf
    }
  }

  private func currentSize() -> UInt64 {
    let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
    return (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
  }

  private let traceEnabled = ProcessInfo.processInfo.environment["LANTERN_TRACE_LOGS"] == "true"

  func trace(_ message: @autoclosure () -> String) {
    guard traceEnabled else { return }
    let text = message()
    os_log("%{public}@", log: logger, type: .debug, text)
    writeToFile(text, level: "TRACE")
  }

  func log(_ message: String) {
    os_log("%{public}@", log: logger, type: .debug, String(describing: message))
    writeToFile(message, level: "DEBUG")
  }

  func info(_ message: String) {
    os_log("%{public}@", log: logger, type: .info, String(describing: message))
    writeToFile(message, level: "INFO")
  }

  func error(_ message: String) {
    os_log("%{public}@", log: logger, type: .error, String(describing: message))
    writeToFile(message, level: "ERROR")
  }

  /// Formats timestamp as: 2026-01-20 16:03:50.628 UTC
  private func formatTimestamp(_ date: Date) -> String {
    formatter.timeZone = utcTimeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return "\(formatter.string(from: date)) UTC"
  }
}
