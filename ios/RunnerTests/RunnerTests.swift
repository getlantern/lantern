@testable import Runner
import Foundation
import XCTest

final class RunnerTests: XCTestCase {

  func testFileStreamerEmitsInitialTail() throws {
    let fileURL = try makeTempLogFile(initialContent: "line-1\nline-2\nline-3\n")
    let streamer = IOSFileLogStreamer(
      fileURL: fileURL,
      maxInitialLines: 2,
      pollInterval: .milliseconds(50))

    let stateQueue = DispatchQueue(label: "RunnerTests.initialTail")
    let initialEmission = expectation(description: "initial tail emitted")
    var initialBatch: [String] = []

    streamer.start { lines in
      stateQueue.sync {
        guard !lines.isEmpty && initialBatch.isEmpty else {
          return
        }
        initialBatch = lines
        initialEmission.fulfill()
      }
    }

    wait(for: [initialEmission], timeout: 1.0)
    streamer.stop()

    let observed = stateQueue.sync { initialBatch }
    XCTAssertEqual(observed, ["line-2", "line-3"])
  }

  func testFileStreamerEmitsAppendedLines() throws {
    let fileURL = try makeTempLogFile(initialContent: "line-1\n")
    let streamer = IOSFileLogStreamer(
      fileURL: fileURL,
      maxInitialLines: 10,
      pollInterval: .milliseconds(50))

    let stateQueue = DispatchQueue(label: "RunnerTests.appendedLines")
    let appendedEmission = expectation(description: "appended batch emitted")
    var emittedBatches: [[String]] = []

    streamer.start { lines in
      stateQueue.sync {
        guard !lines.isEmpty else {
          return
        }
        emittedBatches.append(lines)
        if lines == ["line-2", "line-3"] {
          appendedEmission.fulfill()
        }
      }
    }

    try append("line-2\nline-3\n", to: fileURL)

    wait(for: [appendedEmission], timeout: 2.0)
    streamer.stop()

    let observed = stateQueue.sync { emittedBatches }
    XCTAssertTrue(observed.contains(["line-2", "line-3"]))
  }

  func testFileStreamerBuffersPartialLineUntilNewline() throws {
    let fileURL = try makeTempLogFile()
    let streamer = IOSFileLogStreamer(
      fileURL: fileURL,
      maxInitialLines: 10,
      pollInterval: .milliseconds(50))

    let stateQueue = DispatchQueue(label: "RunnerTests.partialLines")
    let completedLineEmission = expectation(description: "completed line emitted")
    var observedLines: [String] = []

    streamer.start { lines in
      stateQueue.sync {
        guard !lines.isEmpty else {
          return
        }
        observedLines.append(contentsOf: lines)
        if observedLines.contains("partial-line") {
          completedLineEmission.fulfill()
        }
      }
    }

    try append("partial-line", to: fileURL)
    Thread.sleep(forTimeInterval: 0.25)

    let beforeNewline = stateQueue.sync { observedLines }
    XCTAssertFalse(beforeNewline.contains("partial-line"))

    try append("\n", to: fileURL)
    wait(for: [completedLineEmission], timeout: 1.0)
    streamer.stop()

    let finalObserved = stateQueue.sync { observedLines }
    XCTAssertTrue(finalObserved.contains("partial-line"))
  }

  private func makeTempLogFile(initialContent: String = "") throws -> URL {
    let testDirectoryURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("RunnerTests-\(UUID().uuidString)", isDirectory: true)

    try FileManager.default.createDirectory(
      at: testDirectoryURL,
      withIntermediateDirectories: true,
      attributes: nil)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: testDirectoryURL)
    }

    let logFileURL = testDirectoryURL.appendingPathComponent("lantern.log")
    try Data(initialContent.utf8).write(to: logFileURL)
    return logFileURL
  }

  private func append(_ text: String, to fileURL: URL) throws {
    let handle = try FileHandle(forWritingTo: fileURL)
    defer { try? handle.close() }
    handle.seekToEndOfFile()
    handle.write(Data(text.utf8))
  }
}
