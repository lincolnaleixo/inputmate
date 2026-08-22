import Foundation
import InputMateCore

enum ShortcutCategory: String, CaseIterable, Codable, Identifiable {
  case applications = "Applications"
  case shortcuts = "Shortcuts"
  case system = "System & Automation"

  var id: String { rawValue }
}

enum ShortcutAction: Codable, Equatable {
  case openApplication(path: String)
  case openURL(url: String)
  case runShortcut(name: String)
  case postKey(chord: ShortcutChord)
  case transformText(presetID: String)
  case pressMenuItem(path: [String])
  case typeText(text: String)
  case hideOtherApplications
  case showNotificationCenter
  case closeNotifications
  case sleepComputer
}

enum ShortcutActionKind: String, CaseIterable, Identifiable {
  case openApplication = "Open Application"
  case openURL = "Open URL"
  case runShortcut = "Run Apple Shortcut"
  case postKey = "Send Keyboard Shortcut"
  case transformText = "Transform Selected Text"
  case pressMenuItem = "Press Menu Bar Item"
  case typeText = "Type Custom Text"
  case hideOtherApplications = "Hide Other Applications"
  case showNotificationCenter = "Show Notification Center"
  case closeNotifications = "Close Notifications"
  case sleepComputer = "Sleep Computer"

  var id: String { rawValue }
}

extension ShortcutAction {
  var kind: ShortcutActionKind {
    switch self {
    case .openApplication: .openApplication
    case .openURL: .openURL
    case .runShortcut: .runShortcut
    case .postKey: .postKey
    case .transformText: .transformText
    case .pressMenuItem: .pressMenuItem
    case .typeText: .typeText
    case .hideOtherApplications: .hideOtherApplications
    case .showNotificationCenter: .showNotificationCenter
    case .closeNotifications: .closeNotifications
    case .sleepComputer: .sleepComputer
    }
  }

  var category: ShortcutCategory {
    switch self {
    case .openApplication:
      .applications
    case .openURL, .runShortcut, .postKey, .transformText, .pressMenuItem, .typeText:
      .shortcuts
    case .hideOtherApplications, .showNotificationCenter, .closeNotifications,
      .sleepComputer:
      .system
    }
  }
}

struct KeyboardShortcutDefinition: Codable, Identifiable, Equatable {
  var id: String
  var category: ShortcutCategory
  var chord: ShortcutChord
  var displayShortcut: String
  var actionTitle: String
  var action: ShortcutAction
  var isEnabled: Bool
  var appScope: ShortcutAppScope? = nil
}

enum KeyboardShortcutCatalog {
  /// Public factory defaults intentionally contain no machine-specific app
  /// paths, personal automations, or application scopes. Existing customized
  /// definitions remain in the user's local preferences.
  static var definitions: [KeyboardShortcutDefinition] {
    globalDefinitions + appScopedDefinitions
  }

  private static let globalDefinitions: [KeyboardShortcutDefinition] = [
    transformation(
      "translate-spanish",
      keyCode: 122,
      shortcut: "Left ⇧⌃⌥⌘ F1",
      title: "Translate Selection to Spanish",
      presetID: TextTransformationPreset.spanishID
    ),
    transformation(
      "translate-english",
      keyCode: 120,
      shortcut: "Left ⇧⌃⌥⌘ F2",
      title: "Translate Selection to English",
      presetID: TextTransformationPreset.englishID
    ),
    transformation(
      "improve-writing",
      keyCode: 99,
      shortcut: "Left ⇧⌃⌥⌘ F3",
      title: "Improve Selected Text",
      presetID: TextTransformationPreset.improveID
    ),
    KeyboardShortcutDefinition(
      id: "spotlight",
      category: .shortcuts,
      chord: ShortcutChord(keyCode: 118, modifiers: 0, deviceFlags: 0),
      displayShortcut: "F4",
      actionTitle: "Open Spotlight",
      action: .postKey(
        chord: ShortcutChord(
          keyCode: 49,
          modifiers: ShortcutChord.command,
          deviceFlags: 0
        )
      ),
      isEnabled: true
    ),
  ]

  static let appScopedDefinitions: [KeyboardShortcutDefinition] = []

  static var blankDefinition: KeyboardShortcutDefinition {
    KeyboardShortcutDefinition(
      id: UUID().uuidString,
      category: .applications,
      chord: ShortcutChord(keyCode: -1, modifiers: 0, deviceFlags: 0),
      displayShortcut: "Not set",
      actionTitle: "New Shortcut",
      action: .openApplication(path: ""),
      isEnabled: true
    )
  }

  private static func transformation(
    _ id: String,
    keyCode: Int64,
    shortcut: String,
    title: String,
    presetID: String
  ) -> KeyboardShortcutDefinition {
    KeyboardShortcutDefinition(
      id: id,
      category: .shortcuts,
      chord: ShortcutChord(
        keyCode: keyCode,
        modifiers: ShortcutChord.leftHyperModifiers,
        deviceFlags: ShortcutChord.leftHyperDeviceFlags
      ),
      displayShortcut: shortcut,
      actionTitle: title,
      action: .transformText(presetID: presetID),
      isEnabled: true
    )
  }
}
