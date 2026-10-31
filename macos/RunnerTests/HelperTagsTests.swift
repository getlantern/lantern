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

  func testRedactsThePersonalProxiesGroupAndType() {
    XCTAssertEqual(
      redactHelperTags("selected personal-proxies (type=personalProxy)"),
      "selected helper (type=helper)")
    XCTAssertEqual(
      redactHelperTags("{\"tag\":\"personal-proxies\"}"), "{\"tag\":\"helper\"}")
    XCTAssertEqual(redactHelperTags("personalProxyX stays"), "personalProxyX stays")
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

  func testRedactsAFriendsSelection() {
    XCTAssertEqual(
      redactHelperTags("params: [\"server\": \"personal-proxy:\(tag)\"]"),
      "params: [\"server\": \"helper:helper\"]")
    XCTAssertEqual(
      redactHelperTags("outbound/mutableurltest[personal-proxy]"),
      "outbound/mutableurltest[helper]")
    XCTAssertTrue(isPersonalProxySelection("personal-proxy:\(tag)"))
    XCTAssertFalse(isPersonalProxySelection(personalProxiesTag))
  }
}
