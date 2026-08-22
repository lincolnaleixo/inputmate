import Foundation
import Security

enum KeychainSecretStore {
  static let cerebrasService = "com.robot.InputMate.cerebras"
  static let cerebrasAccount = "api-key"

  static func cerebrasAPIKey() -> String? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: cerebrasService,
      kSecAttrAccount: cerebrasAccount,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]

    var result: CFTypeRef?
    guard
      SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func saveCerebrasAPIKey(_ value: String) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
      throw KeychainSecretError.emptyValue
    }

    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: cerebrasService,
      kSecAttrAccount: cerebrasAccount,
    ]
    let attributes: [CFString: Any] = [kSecValueData: data]
    let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

    if updateStatus == errSecItemNotFound {
      var newItem = query
      newItem[kSecValueData] = data
      newItem[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
      let addStatus = SecItemAdd(newItem as CFDictionary, nil)
      guard addStatus == errSecSuccess else {
        throw KeychainSecretError.status(addStatus)
      }
    } else if updateStatus != errSecSuccess {
      throw KeychainSecretError.status(updateStatus)
    }
  }

  static func removeCerebrasAPIKey() throws {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: cerebrasService,
      kSecAttrAccount: cerebrasAccount,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainSecretError.status(status)
    }
  }
}

enum KeychainSecretError: LocalizedError {
  case emptyValue
  case status(OSStatus)

  var errorDescription: String? {
    switch self {
    case .emptyValue:
      "The API key is empty."
    case .status(let status):
      SecCopyErrorMessageString(status, nil) as String?
        ?? "Keychain error \(status)."
    }
  }
}
