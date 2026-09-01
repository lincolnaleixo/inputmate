import Foundation
import InputMateCore
import Security

enum KeychainSecretStore {
  private static let account = "api-key"

  static func apiKey(for provider: AIProvider) -> String? {
    var query = baseQuery(for: provider)
    query[kSecReturnData] = true
    query[kSecMatchLimit] = kSecMatchLimitOne

    var result: CFTypeRef?
    guard
      SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }

  static func saveAPIKey(_ value: String, for provider: AIProvider) throws {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
      throw KeychainSecretError.emptyValue
    }

    let query = baseQuery(for: provider)
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

  static func removeAPIKey(for provider: AIProvider) throws {
    let status = SecItemDelete(baseQuery(for: provider) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainSecretError.status(status)
    }
  }

  private static func baseQuery(for provider: AIProvider) -> [CFString: Any] {
    [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: provider.keychainService,
      kSecAttrAccount: account,
    ]
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
