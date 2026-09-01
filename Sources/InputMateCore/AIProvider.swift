import Foundation

public enum AIProvider: String, CaseIterable, Identifiable, Sendable {
  case cerebras
  case groq

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .cerebras:
      "Cerebras"
    case .groq:
      "Groq"
    }
  }

  public var chatCompletionsURL: URL {
    switch self {
    case .cerebras:
      URL(string: "https://api.cerebras.ai/v1/chat/completions")!
    case .groq:
      URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    }
  }

  public var defaultModel: String {
    switch self {
    case .cerebras:
      "gemma-4-31b"
    case .groq:
      "qwen/qwen3.8-27b"
    }
  }

  public var suggestedModels: [String] {
    switch self {
    case .cerebras:
      ["gemma-4-31b", "gpt-oss-120b", "zai-glm-4.7"]
    case .groq:
      [
        "qwen/qwen3.8-27b",
        "qwen/qwen3.6-27b",
        "openai/gpt-oss-120b",
        "openai/gpt-oss-20b",
      ]
    }
  }

  public var maxCompletionTokens: Int {
    switch self {
    case .cerebras:
      32_768
    case .groq:
      2_048
    }
  }

  public func reasoningEffort(for model: String) -> String? {
    guard self == .groq else { return nil }
    return model.lowercased().hasPrefix("qwen/qwen3.") ? "default" : nil
  }

  public func reasoningFormat(for model: String) -> String? {
    reasoningEffort(for: model) == nil ? nil : "hidden"
  }

  public var keychainService: String {
    switch self {
    case .cerebras:
      "com.robot.InputMate.cerebras"
    case .groq:
      "com.robot.InputMate.groq"
    }
  }
}

public struct AIConfiguration: Equatable, Sendable {
  public let provider: AIProvider
  public let model: String

  public init(provider: AIProvider, model: String) {
    self.provider = provider
    self.model = model
  }

  public var displayName: String {
    "\(provider.displayName) · \(model)"
  }
}

public enum AIConfigurationStore {
  private enum DefaultsKey {
    static let provider = "textTransformationProvider"

    static func model(for provider: AIProvider) -> String {
      "textTransformationModel.\(provider.rawValue)"
    }
  }

  public static func provider(from defaults: UserDefaults = .standard) -> AIProvider {
    guard
      let rawValue = defaults.string(forKey: DefaultsKey.provider),
      let provider = AIProvider(rawValue: rawValue)
    else {
      return .cerebras
    }
    return provider
  }

  public static func model(
    for provider: AIProvider,
    from defaults: UserDefaults = .standard
  ) -> String {
    if let storedModel = defaults.string(forKey: DefaultsKey.model(for: provider))?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      !storedModel.isEmpty
    {
      return storedModel
    }
    return provider.defaultModel
  }

  public static func configuration(
    from defaults: UserDefaults = .standard
  ) -> AIConfiguration {
    let provider = provider(from: defaults)
    return AIConfiguration(
      provider: provider,
      model: model(for: provider, from: defaults)
    )
  }

  public static func setProvider(
    _ provider: AIProvider,
    in defaults: UserDefaults = .standard
  ) {
    defaults.set(provider.rawValue, forKey: DefaultsKey.provider)
  }

  @discardableResult
  public static func setModel(
    _ model: String,
    for provider: AIProvider,
    in defaults: UserDefaults = .standard
  ) -> Bool {
    let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedModel.isEmpty else { return false }
    defaults.set(trimmedModel, forKey: DefaultsKey.model(for: provider))
    return true
  }

  public static func resetModel(
    for provider: AIProvider,
    in defaults: UserDefaults = .standard
  ) {
    defaults.removeObject(forKey: DefaultsKey.model(for: provider))
  }
}
