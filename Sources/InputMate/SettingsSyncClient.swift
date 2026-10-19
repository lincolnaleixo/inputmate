import Foundation
import InputMateCore

/// Talks to the settings server (`server/inputmate-sync.py`) at the URL in the
/// `settingsSyncURL` preference. Without that preference, sync is off.
struct SettingsSyncClient {
  let url: URL

  init?(defaults: UserDefaults) {
    guard
      let text = defaults.string(forKey: "settingsSyncURL")?
        .trimmingCharacters(in: .whitespacesAndNewlines),
      let url = URL(string: text),
      url.scheme?.hasPrefix("http") == true
    else { return nil }
    self.url = url
  }

  func fetch() async throws -> SettingsSyncDocument {
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "GET"
    let (data, response) = try await URLSession.shared.data(for: request)
    try Self.check(response, accepting: [200])
    return try JSONDecoder().decode(SettingsSyncDocument.self, from: data)
  }

  /// Stores `snapshot` if the server is still at `revision`. On a conflict the
  /// server's current document comes back with `stored == false`.
  func push(
    _ snapshot: SettingsSnapshot,
    revision: Int
  ) async throws -> (stored: Bool, document: SettingsSyncDocument) {
    var request = URLRequest(url: url, timeoutInterval: 10)
    request.httpMethod = "PUT"
    request.setValue(String(revision), forHTTPHeaderField: "If-Match")
    request.httpBody = try JSONEncoder().encode(snapshot)
    let (data, response) = try await URLSession.shared.data(for: request)
    try Self.check(response, accepting: [200, 409])
    let document = try JSONDecoder().decode(SettingsSyncDocument.self, from: data)
    return ((response as? HTTPURLResponse)?.statusCode == 200, document)
  }

  private static func check(_ response: URLResponse, accepting codes: Set<Int>) throws {
    guard let status = (response as? HTTPURLResponse)?.statusCode, codes.contains(status) else {
      throw URLError(.badServerResponse)
    }
  }
}
