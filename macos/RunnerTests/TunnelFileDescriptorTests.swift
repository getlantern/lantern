import XCTest

final class TunnelFileDescriptorTests: XCTestCase {
  private typealias Candidate = TunnelFileDescriptor.Candidate
  private let address = "10.10.1.1"

  func testSelectsConfiguredInterfaceInsteadOfLowestOrHighestDescriptor() throws {
    let live = Candidate(descriptor: 20, interfaceName: "utun4", addresses: [address])
    let candidates = [
      Candidate(descriptor: 10, interfaceName: "utun3", addresses: []),
      live,
      Candidate(descriptor: 30, interfaceName: "utun5", addresses: ["192.0.2.1"]),
    ]
    XCTAssertEqual(try TunnelFileDescriptor.select(candidates, addresses: [address]), live)
    XCTAssertEqual(
      try TunnelFileDescriptor.select(candidates.reversed(), addresses: [address]), live)
  }

  func testAcceptsReusedLowerDescriptorForTheLiveInterface() throws {
    let live = Candidate(descriptor: 4, interfaceName: "utun5", addresses: [address])
    let orphan = Candidate(descriptor: 20, interfaceName: "utun4", addresses: [])
    XCTAssertEqual(try TunnelFileDescriptor.select([orphan, live], addresses: [address]), live)
  }

  func testRejectsTwoInterfacesWithTheSameAddress() {
    assertError(
      .ambiguousInterfaces,
      candidates: [
        Candidate(descriptor: 10, interfaceName: "utun3", addresses: [address]),
        Candidate(descriptor: 20, interfaceName: "utun4", addresses: [address]),
      ])
  }

  func testAllowsDuplicateDescriptorsForTheSameInterface() throws {
    let candidates = [
      Candidate(descriptor: 10, interfaceName: "utun4", addresses: [address]),
      Candidate(descriptor: 20, interfaceName: "utun4", addresses: [address]),
    ]
    XCTAssertEqual(
      try TunnelFileDescriptor.select(candidates, addresses: [address]).interfaceName, "utun4")
  }

  func testRejectsAnOrphanEvenWhenItIsTheOnlyDescriptor() {
    assertError(
      .noMatchingInterface,
      candidates: [Candidate(descriptor: 10, interfaceName: "utun3", addresses: [])])
    assertError(.noMatchingInterface, candidates: [])
  }

  func testRequiresEveryConfiguredAddress() {
    assertError(
      .noMatchingInterface,
      candidates: [Candidate(descriptor: 10, interfaceName: "utun3", addresses: [address])],
      addresses: [address, "fdfe:dcba:9876::1"])
  }

  func testComparesIPv6AddressesByValue() throws {
    let live = Candidate(
      descriptor: 20, interfaceName: "utun4", addresses: ["fdfe:dcba:9876::1"])
    XCTAssertEqual(
      try TunnelFileDescriptor.select([live], addresses: ["FDFE:DCBA:9876:0:0:0:0:1"]), live)
  }

  func testRejectsMissingOrInvalidConfiguredAddresses() {
    let candidates = [Candidate(descriptor: 10, interfaceName: "utun3", addresses: [address])]
    for addresses in [[], ["invalid"], [address, "invalid"]] {
      assertError(.missingAddresses, candidates: candidates, addresses: addresses)
    }
  }

  private func assertError(
    _ expected: TunnelFileDescriptor.ResolutionError,
    candidates: [Candidate], addresses: [String]? = nil,
    file: StaticString = #filePath, line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try TunnelFileDescriptor.select(candidates, addresses: addresses ?? [address]),
      file: file, line: line
    ) { error in
      XCTAssertEqual(
        error as? TunnelFileDescriptor.ResolutionError, expected, file: file, line: line)
    }
  }
}
