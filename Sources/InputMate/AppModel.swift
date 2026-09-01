import AppKit
import ApplicationServices
import InputMateCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
  private enum DefaultsKey {
    static let reversesMouseWheel = "reversesMouseWheel"
    static let handlesKeyboardShortcuts = "handlesKeyboardShortcuts"
    static let keyboardShortcutDefinitions = "keyboardShortcutDefinitions"
    static let installedTextTransformationDefaults = "installedTextTransformationDefaults"
    static let textTransformationShortcutVersion = "textTransformationShortcutVersion"
    static let keyboardShortcutPreferenceMigrationVersion =
      "keyboardShortcutPreferenceMigrationVersion"
    static let appScopedShortcutVersion = "appScopedShortcutVersion"
    static let diagnosticAccessibilityAccess = "diagnosticAccessibilityAccess"
    static let diagnosticInputTapRunning = "diagnosticInputTapRunning"
    static let diagnosticInputTapLastAcknowledgedAt =
      "diagnosticInputTapLastAcknowledgedAt"
    static let diagnosticCapsLockHyperMapping = "diagnosticCapsLockHyperMapping"
    static let diagnosticTapState = "diagnosticTapState"
    static let legacyMouseReversal = "isEnabled"
  }

  @Published private(set) var reversesMouseWheel: Bool
  @Published private(set) var handlesKeyboardShortcuts: Bool
  @Published private(set) var shortcutDefinitions: [KeyboardShortcutDefinition]
  @Published private(set) var textTransformationProvider: AIProvider
  @Published private(set) var textTransformationModel: String
  @Published private(set) var hasTextTransformationAPIKey: Bool
  @Published private(set) var hasAccessibilityAccess = false
  @Published private(set) var opensAtLogin = false
  @Published private(set) var statusMessage: String?

  private let defaults: UserDefaults
  private let inputEventTap = InputEventTap()
  private let capsLockHyperMapper = CapsLockHyperMapper()
  private static let currentTextTransformationShortcutVersion = 2
  private static let currentAppScopedShortcutVersion = 1

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    Self.migrateLegacyDefaultsIfNeeded(into: defaults)

    reversesMouseWheel = defaults.bool(forKey: DefaultsKey.reversesMouseWheel)
    handlesKeyboardShortcuts = defaults.bool(forKey: DefaultsKey.handlesKeyboardShortcuts)
    shortcutDefinitions = Self.loadShortcutDefinitions(from: defaults)
    let aiConfiguration = AIConfigurationStore.configuration(from: defaults)
    textTransformationProvider = aiConfiguration.provider
    textTransformationModel = aiConfiguration.model
    hasTextTransformationAPIKey = Self.hasAPIKey(for: aiConfiguration.provider)
    Self.installTextTransformationDefaultsIfNeeded(
      into: &shortcutDefinitions,
      defaults: defaults
    )
    Self.migrateTextTransformationShortcutsIfNeeded(
      definitions: &shortcutDefinitions,
      defaults: defaults
    )
    Self.migrateAppScopedShortcutsIfNeeded(
      definitions: &shortcutDefinitions,
      defaults: defaults
    )
    Self.migrateKeyboardShortcutPreferencesIfNeeded(
      definitions: &shortcutDefinitions,
      defaults: defaults
    )
    defaults.set(
      capsLockHyperMapper.maintain(force: true),
      forKey: DefaultsKey.diagnosticCapsLockHyperMapping
    )
    configureEventTap()
    refreshState()

    if requiresAccessibility && !hasAccessibilityAccess {
      requestAccessibilityAccess()
    }
    Task { [weak self] in
      await self?.monitorAccessibility()
    }
  }

  var requiresAccessibility: Bool {
    reversesMouseWheel || handlesKeyboardShortcuts
  }

  var isActivelyHandlingInput: Bool {
    requiresAccessibility && hasAccessibilityAccess && inputEventTap.isResponsive
  }

  var enabledShortcutCount: Int {
    shortcutDefinitions.count(where: \.isEnabled)
  }

  var menuBarSymbol: String {
    if requiresAccessibility && !hasAccessibilityAccess {
      return "exclamationmark.triangle"
    }
    return isActivelyHandlingInput ? "command.circle.fill" : "command.circle"
  }

  func setReversesMouseWheel(_ enabled: Bool) {
    reversesMouseWheel = enabled
    defaults.set(enabled, forKey: DefaultsKey.reversesMouseWheel)
    applyFeatureChange()
  }

  func setHandlesKeyboardShortcuts(_ enabled: Bool) {
    handlesKeyboardShortcuts = enabled
    defaults.set(enabled, forKey: DefaultsKey.handlesKeyboardShortcuts)
    applyFeatureChange()
  }

  func setShortcutEnabled(id: String, enabled: Bool) {
    guard let index = shortcutDefinitions.firstIndex(where: { $0.id == id }) else { return }

    if enabled,
      let conflict = ShortcutScopePolicy.conflict(
        in: shortcutDefinitions,
        excludingID: id,
        chord: shortcutDefinitions[index].chord,
        scope: shortcutDefinitions[index].appScope,
        id: { $0.id },
        isEnabled: { $0.isEnabled },
        chord: { $0.chord },
        scope: { $0.appScope }
      )
    {
      statusMessage = "That shortcut is already used by \(conflict.actionTitle)."
      return
    }

    shortcutDefinitions[index].isEnabled = enabled
    persistShortcutDefinitions()
  }

  func saveShortcut(_ shortcut: KeyboardShortcutDefinition) {
    var normalizedShortcut = shortcut
    normalizedShortcut.category = shortcut.action.category

    if let index = shortcutDefinitions.firstIndex(where: { $0.id == shortcut.id }) {
      shortcutDefinitions[index] = normalizedShortcut
    } else {
      shortcutDefinitions.append(normalizedShortcut)
    }
    persistShortcutDefinitions()
  }

  @discardableResult
  func duplicateShortcut(id: String) -> String? {
    guard var copy = shortcutDefinitions.first(where: { $0.id == id }) else { return nil }
    copy.id = UUID().uuidString
    copy.actionTitle += " Copy"
    copy.isEnabled = false
    shortcutDefinitions.append(copy)
    persistShortcutDefinitions()
    return copy.id
  }

  func deleteShortcuts(ids: Set<String>) {
    shortcutDefinitions.removeAll(where: { ids.contains($0.id) })
    persistShortcutDefinitions()
  }

  func resetShortcuts() {
    shortcutDefinitions = Self.defaultShortcutDefinitions
    persistShortcutDefinitions()
  }

  func setTextTransformationProvider(_ provider: AIProvider) {
    AIConfigurationStore.setProvider(provider, in: defaults)
    textTransformationProvider = provider
    textTransformationModel = AIConfigurationStore.model(for: provider, from: defaults)
    hasTextTransformationAPIKey = Self.hasAPIKey(for: provider)
    statusMessage = nil
  }

  @discardableResult
  func saveTextTransformationModel(_ value: String) -> Bool {
    guard
      AIConfigurationStore.setModel(
        value,
        for: textTransformationProvider,
        in: defaults
      )
    else {
      statusMessage = "Enter a model ID."
      return false
    }

    textTransformationModel = AIConfigurationStore.model(
      for: textTransformationProvider,
      from: defaults
    )
    statusMessage = nil
    return true
  }

  func resetTextTransformationModel() {
    AIConfigurationStore.resetModel(for: textTransformationProvider, in: defaults)
    textTransformationModel = textTransformationProvider.defaultModel
    statusMessage = nil
  }

  @discardableResult
  func saveTextTransformationAPIKey(_ value: String) -> Bool {
    do {
      try KeychainSecretStore.saveAPIKey(value, for: textTransformationProvider)
      hasTextTransformationAPIKey = true
      statusMessage = nil
      return true
    } catch {
      hasTextTransformationAPIKey = Self.hasAPIKey(for: textTransformationProvider)
      statusMessage = "Could not save the API key: \(error.localizedDescription)"
      return false
    }
  }

  func removeTextTransformationAPIKey() {
    do {
      try KeychainSecretStore.removeAPIKey(for: textTransformationProvider)
      hasTextTransformationAPIKey = false
      statusMessage =
        "The \(textTransformationProvider.displayName) API key was removed from Keychain."
    } catch {
      hasTextTransformationAPIKey = Self.hasAPIKey(for: textTransformationProvider)
      statusMessage = "Could not remove the API key: \(error.localizedDescription)"
    }
  }

  func setOpensAtLogin(_ enabled: Bool) {
    statusMessage = nil

    do {
      if enabled {
        try SMAppService.mainApp.register()
      } else {
        try SMAppService.mainApp.unregister()
      }
      opensAtLogin = SMAppService.mainApp.status == .enabled
    } catch {
      opensAtLogin = SMAppService.mainApp.status == .enabled
      statusMessage = "Could not update the login setting: \(error.localizedDescription)"
    }
  }

  func requestAccessibilityAccess() {
    let options =
      [
        "AXTrustedCheckOptionPrompt": true
      ] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
  }

  func openAccessibilitySettings() {
    guard
      let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
      )
    else { return }
    NSWorkspace.shared.open(url)
  }

  func refreshState() {
    hasAccessibilityAccess = AXIsProcessTrusted()
    defaults.set(hasAccessibilityAccess, forKey: DefaultsKey.diagnosticAccessibilityAccess)
    defaults.set(
      capsLockHyperMapper.maintain(),
      forKey: DefaultsKey.diagnosticCapsLockHyperMapping
    )
    opensAtLogin = SMAppService.mainApp.status == .enabled
    configureEventTap()

    guard requiresAccessibility else {
      inputEventTap.stop()
      defaults.set(false, forKey: DefaultsKey.diagnosticInputTapRunning)
      return
    }

    if hasAccessibilityAccess {
      if !inputEventTap.maintainHealth() {
        statusMessage = "Input monitoring could not be started."
      }
    } else {
      inputEventTap.stop()
    }
    defaults.set(inputEventTap.isResponsive, forKey: DefaultsKey.diagnosticInputTapRunning)
    defaults.set(inputEventTap.diagnosticState, forKey: DefaultsKey.diagnosticTapState)
    if let acknowledgedAt = inputEventTap.lastDeliveryAcknowledgedAt {
      defaults.set(
        acknowledgedAt,
        forKey: DefaultsKey.diagnosticInputTapLastAcknowledgedAt
      )
    } else {
      defaults.removeObject(forKey: DefaultsKey.diagnosticInputTapLastAcknowledgedAt)
    }
  }

  func monitorAccessibility() async {
    while !Task.isCancelled {
      refreshState()
      try? await Task.sleep(for: .seconds(1))
    }
  }

  private func applyFeatureChange() {
    statusMessage = nil
    configureEventTap()
    if requiresAccessibility {
      requestAccessibilityAccess()
    }
    refreshState()
  }

  private func configureEventTap() {
    inputEventTap.reversesMouseWheel = reversesMouseWheel
    inputEventTap.handlesKeyboardShortcuts = handlesKeyboardShortcuts
    inputEventTap.updateKeyboardShortcuts(shortcutDefinitions)
  }

  private func persistShortcutDefinitions() {
    do {
      let data = try JSONEncoder().encode(shortcutDefinitions)
      defaults.set(data, forKey: DefaultsKey.keyboardShortcutDefinitions)
      inputEventTap.updateKeyboardShortcuts(shortcutDefinitions)
      statusMessage = nil
    } catch {
      statusMessage = "Could not save keyboard shortcuts: \(error.localizedDescription)"
    }
  }

  private static var defaultShortcutDefinitions: [KeyboardShortcutDefinition] {
    ShortcutPreferencePolicy.sanitizedDefaults(
      from: KeyboardShortcutCatalog.definitions,
      chord: { $0.chord }
    )
  }

  private static func loadShortcutDefinitions(
    from defaults: UserDefaults
  ) -> [KeyboardShortcutDefinition] {
    guard
      let data = defaults.data(forKey: DefaultsKey.keyboardShortcutDefinitions),
      let definitions = try? JSONDecoder().decode(
        [KeyboardShortcutDefinition].self,
        from: data
      )
    else {
      return defaultShortcutDefinitions
    }
    return definitions.map { definition in
      var normalizedDefinition = definition
      normalizedDefinition.category = definition.action.category
      return normalizedDefinition
    }
  }

  private static func installTextTransformationDefaultsIfNeeded(
    into definitions: inout [KeyboardShortcutDefinition],
    defaults: UserDefaults
  ) {
    guard !defaults.bool(forKey: DefaultsKey.installedTextTransformationDefaults) else {
      return
    }

    let transformationIDs = Set(["translate-spanish", "improve-writing", "translate-english"])
    let existingIDs = Set(definitions.map(\.id))
    definitions.append(
      contentsOf: KeyboardShortcutCatalog.definitions.filter {
        transformationIDs.contains($0.id) && !existingIDs.contains($0.id)
      }
    )

    if let data = try? JSONEncoder().encode(definitions) {
      defaults.set(data, forKey: DefaultsKey.keyboardShortcutDefinitions)
    }
    defaults.set(true, forKey: DefaultsKey.installedTextTransformationDefaults)
  }

  private static func migrateTextTransformationShortcutsIfNeeded(
    definitions: inout [KeyboardShortcutDefinition],
    defaults: UserDefaults
  ) {
    guard
      defaults.integer(forKey: DefaultsKey.textTransformationShortcutVersion)
        < currentTextTransformationShortcutVersion
    else { return }

    let transformationIDs = Set([
      TextTransformationPreset.spanishID,
      TextTransformationPreset.englishID,
      TextTransformationPreset.improveID,
    ])
    let replacements = Dictionary(
      uniqueKeysWithValues: KeyboardShortcutCatalog.definitions
        .filter { transformationIDs.contains($0.id) }
        .map { ($0.id, $0) }
    )

    for index in definitions.indices {
      guard let replacement = replacements[definitions[index].id] else { continue }
      definitions[index].chord = replacement.chord
      definitions[index].displayShortcut = replacement.displayShortcut
    }

    if let data = try? JSONEncoder().encode(definitions) {
      defaults.set(data, forKey: DefaultsKey.keyboardShortcutDefinitions)
      defaults.set(
        currentTextTransformationShortcutVersion,
        forKey: DefaultsKey.textTransformationShortcutVersion
      )
    }
  }

  /// Adds application-scoped defaults from earlier versions. Versioning allows
  /// later corrections without replacing user-customized shortcut definitions.
  private static func migrateAppScopedShortcutsIfNeeded(
    definitions: inout [KeyboardShortcutDefinition],
    defaults: UserDefaults
  ) {
    guard
      defaults.integer(forKey: DefaultsKey.appScopedShortcutVersion)
        < currentAppScopedShortcutVersion
    else { return }

    let existingIDs = Set(definitions.map(\.id))
    definitions.append(
      contentsOf: KeyboardShortcutCatalog.appScopedDefinitions.filter {
        !existingIDs.contains($0.id)
      }
    )

    guard let data = try? JSONEncoder().encode(definitions) else { return }
    defaults.set(data, forKey: DefaultsKey.keyboardShortcutDefinitions)
    defaults.set(
      currentAppScopedShortcutVersion,
      forKey: DefaultsKey.appScopedShortcutVersion
    )
  }

  private static func migrateKeyboardShortcutPreferencesIfNeeded(
    definitions: inout [KeyboardShortcutDefinition],
    defaults: UserDefaults
  ) {
    let migration = ShortcutPreferencePolicy.migrate(
      definitions,
      fromVersion: defaults.integer(
        forKey: DefaultsKey.keyboardShortcutPreferenceMigrationVersion
      ),
      chord: { $0.chord }
    )
    guard migration.didMigrate else { return }

    definitions = migration.definitions
    guard let data = try? JSONEncoder().encode(definitions) else { return }
    defaults.set(data, forKey: DefaultsKey.keyboardShortcutDefinitions)
    defaults.set(
      migration.version,
      forKey: DefaultsKey.keyboardShortcutPreferenceMigrationVersion
    )
  }

  private static func migrateLegacyDefaultsIfNeeded(into defaults: UserDefaults) {
    if defaults.object(forKey: DefaultsKey.reversesMouseWheel) == nil {
      let legacyDefaults = UserDefaults(suiteName: "com.robot.ScrollMate")
      let legacyValue = legacyDefaults?.bool(forKey: DefaultsKey.legacyMouseReversal) ?? false
      defaults.set(legacyValue, forKey: DefaultsKey.reversesMouseWheel)
    }

    if defaults.object(forKey: DefaultsKey.handlesKeyboardShortcuts) == nil {
      defaults.set(true, forKey: DefaultsKey.handlesKeyboardShortcuts)
    }
  }

  private static func hasAPIKey(for provider: AIProvider) -> Bool {
    guard let apiKey = KeychainSecretStore.apiKey(for: provider) else { return false }
    return !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
