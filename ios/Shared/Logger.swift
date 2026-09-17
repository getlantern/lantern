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

/// Writes to `lantern_ios.log` in the shared logs directory. The tunnel extension
/// appends to the same file, so writes open/append/close instead of holding a
/// handle, and only the app process rotates.
///
/// Rotation matches FileLogPrinter (logger_service.dart) and radiance: 5 MB
/// live file, two gzipped `<name>-<stamp>.log.gz` backups. The name matters:
/// the issue-report archiver globs `*.log` and reads every match in full.
class LanternLogger {
  private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Lantern-IOS")
  private let logFileURL: URL
  private let formatter = DateFormatter()
  private let utcTimeZone = TimeZone(identifier: "UTC")
  private let queue = DispatchQueue(label: "LanternLoggerQueue", qos: .utility)

  private static let maxFileBytes: UInt64 = 5 * 1024 * 1024
  private static let maxBackups = 2
  private static let checkIntervalBytes = 256 * 1024
  private static let backupExt = ".log.gz"

  /// Only the app rotates, so it never races the extension.
  private let canRotate = Bundle.main.bundleURL.pathExtension != "appex"
  /// Bytes appended since the last size check, so we don't stat on every line.
  private var sinceCheck = 0

  init() {
    // Ensure Logs directory exists
    let logsDir = FilePath.logsDirectory
    if !FileManager.default.fileExists(atPath: logsDir.path) {
      try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
    }

    // Log file path
    self.logFileURL = logsDir.appendingPathComponent("lantern_ios.log")

    // Create empty file if missing
    if !FileManager.default.fileExists(atPath: logFileURL.path) {
      FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
    if canRotate {
      queue.async { [weak self] in self?.rotateIfNeeded() }
    }
  }

  private func writeToFile(_ message: String) {
    queue.async { [weak self] in
      guard let self = self else { return }
      let timestamp = formatTimestamp(Date.now)
      let formatted = "time=\"\(timestamp)\" \(message)\n"
      guard let data = formatted.data(using: .utf8) else { return }
      if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
        // Exclusive lock so an append never lands mid-rotation in the other process.
        flock(fileHandle.fileDescriptor, LOCK_EX)
        fileHandle.seekToEndOfFile()
        fileHandle.write(data)
        try? fileHandle.close()  // releases the lock
      }
      guard canRotate else { return }
      sinceCheck += data.count
      if sinceCheck >= Self.checkIntervalBytes {
        sinceCheck = 0
        rotateIfNeeded()
      }
    }
  }

  // MARK: - Rotation (runs on `queue`)

  private func rotateIfNeeded() {
    let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path)
    let size = (attrs?[.size] as? NSNumber)?.uint64Value ?? 0
    guard size >= Self.maxFileBytes else { return }
    // Hold the lock from snapshot through truncate so no append from the
    // extension can slip in between and be lost.
    guard let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
    flock(handle.fileDescriptor, LOCK_EX)
    do {
      try compressToBackup()
    } catch {
      logger.error("Log rotation failure: \(error.localizedDescription, privacy: .public)")
    }
    // Truncate in place (not rename) so the extension keeps writing to the same
    // file. Done even if compression failed (e.g. disk full), so the live file
    // stays bounded.
      try? handle.truncate(atOffset: 0)
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
      var inBuf = [UInt8](input.readData(ofLength: chunk))
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
              output.write(Data(bytes: outPtr.baseAddress!, count: produced))
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
  }

  private let traceEnabled = ProcessInfo.processInfo.environment["LANTERN_TRACE_LOGS"] == "true"

  func trace(_ message: @autoclosure () -> String) {
    guard traceEnabled else { return }
    let text = message()
    logger.debug("\(text, privacy: .public)")
    writeToFile("[TRACE] \(text)")
  }

  func log(_ message: String) {
    logger.debug("\(message, privacy: .public)")
    writeToFile("[DEBUG] \(message)")
  }

  func info(_ message: String) {
    logger.info("\(message, privacy: .public)")
    writeToFile("[INFO] \(message)")
  }

  func error(_ message: String) {
    logger.error("\(message, privacy: .public)")
    writeToFile("[ERROR] \(message)")
  }

  func logFile() -> URL {
    return logFileURL
  }

  /// Formats timestamp as: 2026-01-20 16:03:50.628 UTC
  private func formatTimestamp(_ date: Date) -> String {
    formatter.timeZone = utcTimeZone
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    return "\(formatter.string(from: date)) UTC"
  }
}
