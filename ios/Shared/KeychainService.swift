//
//  KeychainService.swift
//  Runner
//
//  Created by jigar fumakiya on 02/01/24.
//

import Foundation
import Security

// Service that store deviced user id to keychanin
// so when user comes back fetch there IDs from key chain
class KeychainService {
  static func save(_ data: Data, for key: String) {
    let query =
      [
        kSecClass as String: kSecClassGenericPassword as String,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
      ] as [String: Any]

    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
  }

  static func load(key: String) -> Data? {
    let query =
      [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: kCFBooleanTrue!,
        kSecMatchLimit as String: kSecMatchLimitOne,
      ] as [String: Any]

    var dataTypeRef: AnyObject? = nil
    let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

    if status == noErr {
      return dataTypeRef as? Data
    } else {
      return nil
    }
  }
}

class DeviceIdentifier {
  static let key = "lantern.udid"

  static func getUDID() -> String {
    if let retrievedData = KeychainService.load(key: key),
      let udid = String(data: retrievedData, encoding: .utf8)
    {
      return udid
    } else {
      let newUDID = UUID().uuidString
      KeychainService.save(newUDID.data(using: .utf8)!, for: key)
      return newUDID
    }
  }
}
