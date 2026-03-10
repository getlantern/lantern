@testable import Runner
import XCTest

final class RunnerTests: XCTestCase {

  func testBatchDifferEmitsInitialSnapshot() {
    var differ = LogBatchDiffer()

    let batch = differ.consume(["line-1", "line-2"])

    XCTAssertEqual(batch, ["line-1", "line-2"])
  }

  func testBatchDifferEmitsOnlyAppendedLines() {
    var differ = LogBatchDiffer()
    _ = differ.consume(["line-1", "line-2"])

    let batch = differ.consume(["line-1", "line-2", "line-3", "line-4"])

    XCTAssertEqual(batch, ["line-3", "line-4"])
  }

  func testBatchDifferHandlesRollingWindowWithoutDroppingNewLines() {
    var differ = LogBatchDiffer()
    _ = differ.consume(["line-1", "line-2", "line-3"])

    let batch = differ.consume(["line-2", "line-3", "line-4"])

    XCTAssertEqual(batch, ["line-4"])
  }

  func testBatchDifferReturnsCurrentSnapshotOnNoOverlap() {
    var differ = LogBatchDiffer()
    _ = differ.consume(["line-1", "line-2"])

    let batch = differ.consume(["other-1", "other-2"])

    XCTAssertEqual(batch, ["other-1", "other-2"])
  }
}
