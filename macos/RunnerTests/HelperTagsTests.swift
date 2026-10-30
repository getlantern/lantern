import Foundation
import XCTest

final class HelperTagsTests: XCTestCase {
  private let tag = "helper-0123456789ab"

  func testRedactsEveryHelperTag() {
    XCTAssertEqual(
      redactHelperTags("outbound/samizdat[\(tag)] and helper-ffffffffffff"),
      "outbound/samizdat[helper] and helper")
    XCTAssertEqual(redactHelperTags("\(tag)_failed"), "helper_failed")
    XCTAssertEqual(redactHelperTags("{\"tag\":\"\(tag)\"}"), "{\"tag\":\"helper\"}")
  }

  func testLeavesOtherTextAlone() {
    XCTAssertEqual(redactHelperTags("helper-short stays"), "helper-short stays")
    XCTAssertEqual(redactHelperTags("x\(tag)"), "x\(tag)")
    XCTAssertEqual(redactHelperTags("lantern-1"), "lantern-1")
  }

  func testServerLocationEventsLogOnlyTheirType() {
    let message = "{\"tag\":\"\(tag)\",\"location\":{\"city\":\"Berlin\"}}"
    XCTAssertEqual(
      loggableFlutterEvent(type: "server-location", message: message), "server-location")
  }

  func testOtherEventsLogARedactedMessage() {
    XCTAssertEqual(
      loggableFlutterEvent(type: "config", message: "using \(tag)"), "config - using helper")
  }
}
