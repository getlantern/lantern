@testable import Runner
import Foundation
import XCTest

final class RunnerTests: XCTestCase {

  func testReadLastLinesReturnsTail() throws {
    let tempFile = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let content = (1...8).map { "line-\($0)" }.joined(separator: "\n")
    try content.write(to: tempFile, atomically: true, encoding: .utf8)

    let lines = try LogTailer.readLastLines(path: tempFile.path, maxLines: 3)
    XCTAssertEqual(lines, ["line-6", "line-7", "line-8"])
  }

  func testReadLastLinesReturnsAllWhenFileHasFewerLinesThanLimit() throws {
    let tempFile = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    defer {
      try? FileManager.default.removeItem(at: tempFile)
    }

    let content = ["a", "b", "c"].joined(separator: "\n")
    try content.write(to: tempFile, atomically: true, encoding: .utf8)

    let lines = try LogTailer.readLastLines(path: tempFile.path, maxLines: 10)
    XCTAssertEqual(lines, ["a", "b", "c"])
  }
}
