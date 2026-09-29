import Darwin
import Foundation
import Network

enum TunnelFileDescriptor {
  struct Candidate: Equatable {
    let descriptor: Int32
    let interfaceName: String
    let addresses: [String]
  }

  enum ResolutionError: LocalizedError, Equatable {
    case missingAddresses
    case noMatchingInterface
    case ambiguousInterfaces

    var errorDescription: String? {
      switch self {
      case .missingAddresses:
        return "Cannot identify the tunnel without valid configured addresses"
      case .noMatchingInterface:
        return "No tunnel interface matches the configured addresses"
      case .ambiguousInterfaces:
        return "Multiple tunnel interfaces match the configured addresses"
      }
    }
  }

  /// Returns a matching descriptor borrowed from NetworkExtension; it must not be closed here.
  static func resolve(addresses: [String]) throws -> Candidate {
    let interfaces = try interfaceAddresses()
    var candidates: [Candidate] = []
    for descriptor in 0..<getdtablesize() {
      guard let name = interfaceName(descriptor), let addresses = interfaces[name] else {
        continue
      }
      candidates.append(
        Candidate(descriptor: descriptor, interfaceName: name, addresses: addresses))
    }
    return try select(candidates, addresses: addresses)
  }

  static func select(_ candidates: [Candidate], addresses: [String]) throws -> Candidate {
    let expected = Set(addresses.compactMap(addressBytes))
    guard !expected.isEmpty, addresses.allSatisfy({ addressBytes($0) != nil }) else {
      throw ResolutionError.missingAddresses
    }
    let matches = candidates.filter {
      expected.isSubset(of: Set($0.addresses.compactMap(addressBytes)))
    }
    guard let match = matches.first else {
      throw ResolutionError.noMatchingInterface
    }
    // Reused descriptor numbers cannot distinguish a new tunnel from an orphan.
    guard matches.allSatisfy({ $0.interfaceName == match.interfaceName }) else {
      throw ResolutionError.ambiguousInterfaces
    }
    return match
  }

  private static func addressBytes(_ address: String) -> Data? {
    IPv4Address(address)?.rawValue ?? IPv6Address(address)?.rawValue
  }

  private static func interfaceName(_ descriptor: Int32) -> String? {
    var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
    var length = socklen_t(name.count)
    guard getsockopt(descriptor, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, &name, &length) == 0
    else {
      return nil
    }
    let value = String(cString: name)
    guard value.hasPrefix("utun"), UInt32(value.dropFirst(4)) != nil else {
      return nil
    }
    return value
  }

  private static func interfaceAddresses() throws -> [String: [String]] {
    var head: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&head) == 0 else {
      throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
    }
    defer { freeifaddrs(head) }
    var result: [String: [String]] = [:]
    var next = head
    while let current = next {
      next = current.pointee.ifa_next
      guard let address = current.pointee.ifa_addr,
        address.pointee.sa_family == AF_INET || address.pointee.sa_family == AF_INET6,
        current.pointee.ifa_flags & UInt32(IFF_UP) != 0
      else {
        continue
      }
      var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
      guard
        getnameinfo(
          address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
          nil, 0, NI_NUMERICHOST) == 0
      else {
        continue
      }
      let name = String(cString: current.pointee.ifa_name)
      result[name, default: []].append(String(cString: host))
    }
    return result
  }
}
