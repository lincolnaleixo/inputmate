import Foundation

/// The preferences shared between a person's Macs. API keys and the sync
/// credentials never travel; they stay in each Mac's Keychain.
public struct SettingsSnapshot: Codable, Equatable, Sendable {
  public var reversesMouseWheel: Bool
  public var handlesKeyboardShortcuts: Bool
  /// The JSON of the keyboard shortcut definitions, exactly as stored in preferences.
  public var shortcuts: String
  public var provider: String
  /// Models chosen away from the provider default, by provider raw value.
  public var models: [String: String]

  public init(
    reversesMouseWheel: Bool,
    handlesKeyboardShortcuts: Bool,
    shortcuts: String,
    defaults: UserDefaults = .standard
  ) {
    self.reversesMouseWheel = reversesMouseWheel
    self.handlesKeyboardShortcuts = handlesKeyboardShortcuts
    self.shortcuts = shortcuts
    provider = AIConfigurationStore.provider(from: defaults).rawValue
    models = Dictionary(
      uniqueKeysWithValues: AIProvider.allCases.compactMap { provider in
        let model = AIConfigurationStore.model(for: provider, from: defaults)
        return model == provider.defaultModel ? nil : (provider.rawValue, model)
      }
    )
  }

  /// Writes the AI choices to preferences; the caller applies the other fields.
  public func applyAIConfiguration(to defaults: UserDefaults = .standard) {
    if let provider = AIProvider(rawValue: provider) {
      AIConfigurationStore.setProvider(provider, in: defaults)
    }
    for provider in AIProvider.allCases {
      if let model = models[provider.rawValue] {
        AIConfigurationStore.setModel(model, for: provider, in: defaults)
      } else {
        AIConfigurationStore.resetModel(for: provider, in: defaults)
      }
    }
  }
}

/// What the settings server stores: the snapshot and the revision it is at.
public struct SettingsSyncDocument: Codable, Equatable, Sendable {
  public var rev: Int
  public var data: SettingsSnapshot?

  public init(rev: Int, data: SettingsSnapshot?) {
    self.rev = rev
    self.data = data
  }
}
