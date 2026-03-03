import Combine
@testable import Runner
import XCTest

class RunnerTests: XCTestCase {

  func testDeltaLinesForSimpleAppend() {
    let delta = IOSCommandLogStreamer.deltaLines(
      previous: ["a", "b"],
      current: ["a", "b", "c", "d"])

    XCTAssertEqual(delta, ["c", "d"])
  }

  func testDeltaLinesForSlidingWindow() {
    let delta = IOSCommandLogStreamer.deltaLines(
      previous: ["a", "b", "c"],
      current: ["b", "c", "d"])

    XCTAssertEqual(delta, ["d"])
  }

  func testStreamerEmitsOnlyIncrementalLines() {
    let fakeClient = FakeCommandLogClient()
    let streamer = IOSCommandLogStreamer(client: fakeClient)
    var emitted: [[String]] = []

    streamer.start { lines in
      emitted.append(lines)
    }

    fakeClient.subject.send([])
    fakeClient.subject.send(["line-1", "line-2"])
    fakeClient.subject.send(["line-1", "line-2", "line-3"])
    fakeClient.subject.send(["line-2", "line-3", "line-4"])

    XCTAssertEqual(emitted, [["line-1", "line-2"], ["line-3"], ["line-4"]])
    XCTAssertEqual(fakeClient.connectCallCount, 1)

    streamer.stop()

    XCTAssertEqual(fakeClient.disconnectCallCount, 1)
  }

  func testStreamerHandlesLogReset() {
    let fakeClient = FakeCommandLogClient()
    let streamer = IOSCommandLogStreamer(client: fakeClient)
    var emitted: [[String]] = []

    streamer.start { lines in
      emitted.append(lines)
    }

    fakeClient.subject.send(["old-1", "old-2"])
    fakeClient.subject.send([])
    fakeClient.subject.send(["new-1"])

    XCTAssertEqual(emitted, [["old-1", "old-2"], ["new-1"]])
  }
}

private final class FakeCommandLogClient: IOSCommandLogClient {
  let subject = PassthroughSubject<[String], Never>()
  private(set) var connectCallCount = 0
  private(set) var disconnectCallCount = 0

  var logsPublisher: AnyPublisher<[String], Never> {
    subject.eraseToAnyPublisher()
  }

  func connect() {
    connectCallCount += 1
  }

  func disconnect() {
    disconnectCallCount += 1
  }
}
