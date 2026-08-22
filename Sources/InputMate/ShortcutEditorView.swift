import AppKit
import InputMateCore
import SwiftUI
import UniformTypeIdentifiers

struct ShortcutEditorContext: Identifiable {
  let id = UUID()
  let definition: KeyboardShortcutDefinition
}

struct ShortcutEditorView: View {
  @Environment(\.dismiss) private var dismiss

  private let shortcutID: String
  private let existingDefinitions: [KeyboardShortcutDefinition]
  private let onSave: (KeyboardShortcutDefinition) -> Void

  @State private var isEnabled: Bool
  @State private var chord: ShortcutChord
  @State private var displayShortcut: String
  @State private var actionTitle: String
  @State private var actionKind: ShortcutActionKind
  @State private var applicationPath: String
  @State private var urlString: String
  @State private var appleShortcutName: String
  @State private var outputChord: ShortcutChord
  @State private var outputDisplayShortcut: String
  @State private var transformationPresetID: String
  @State private var menuItemPathText: String
  @State private var customText: String
  @State private var scopedBundleIDs: [String]

  init(
    definition: KeyboardShortcutDefinition,
    existingDefinitions: [KeyboardShortcutDefinition],
    onSave: @escaping (KeyboardShortcutDefinition) -> Void
  ) {
    shortcutID = definition.id
    self.existingDefinitions = existingDefinitions
    self.onSave = onSave

    _isEnabled = State(initialValue: definition.isEnabled)
    _chord = State(initialValue: definition.chord)
    _displayShortcut = State(initialValue: definition.displayShortcut)
    _actionTitle = State(initialValue: definition.actionTitle)
    _actionKind = State(initialValue: definition.action.kind)

    var initialApplicationPath = ""
    var initialURL = "https://"
    var initialAppleShortcutName = ""
    var initialOutputChord = ShortcutChord(keyCode: -1, modifiers: 0, deviceFlags: 0)
    var initialTransformationPresetID = TextTransformationPreset.improveID
    var initialMenuItemPathText = ""
    var initialCustomText = ""

    switch definition.action {
    case .openApplication(let path):
      initialApplicationPath = path
    case .openURL(let url):
      initialURL = url
    case .runShortcut(let name):
      initialAppleShortcutName = name
    case .postKey(let chord):
      initialOutputChord = chord
    case .transformText(let presetID):
      initialTransformationPresetID = presetID
    case .pressMenuItem(let path):
      initialMenuItemPathText = path.joined(separator: " > ")
    case .typeText(let text):
      initialCustomText = text
    case .hideOtherApplications, .showNotificationCenter, .closeNotifications,
      .sleepComputer:
      break
    }

    _applicationPath = State(initialValue: initialApplicationPath)
    _urlString = State(initialValue: initialURL)
    _appleShortcutName = State(initialValue: initialAppleShortcutName)
    _outputChord = State(initialValue: initialOutputChord)
    _outputDisplayShortcut = State(
      initialValue: ShortcutFormatter.string(for: initialOutputChord)
    )
    _transformationPresetID = State(initialValue: initialTransformationPresetID)
    _menuItemPathText = State(initialValue: initialMenuItemPathText)
    _customText = State(initialValue: initialCustomText)
    _scopedBundleIDs = State(initialValue: definition.appScope?.bundleIdentifiers ?? [])
  }

  var body: some View {
    VStack(spacing: 0) {
      Form {
        Section("Shortcut") {
          Toggle("Enabled", isOn: $isEnabled)

          TextField("Name", text: $actionTitle)

          LabeledContent("Trigger") {
            ShortcutRecorderView(
              chord: $chord,
              displayShortcut: $displayShortcut
            )
            .frame(width: 190)
          }

          if !isTriggerValid {
            Label(
              "Record a shortcut with a modifier, or use a function key.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
          } else if let conflict {
            Label(
              "Already used by “\(conflict.actionTitle)”.",
              systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.red)
          } else {
            Text("Left and right modifier keys are stored independently.")
              .font(.caption)
              .foregroundStyle(.secondary)

            if !coexistingTitles.isEmpty {
              Text("Also used by \(coexistingTitles.joined(separator: ", ")) in other apps.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }

        Section("Applies To") {
          LabeledContent("Applications") {
            HStack {
              if scopedBundleIDs.isEmpty {
                Text("All applications")
                  .foregroundStyle(.secondary)
              } else {
                Text("\(scopedBundleIDs.count) selected")
                  .foregroundStyle(.secondary)
              }
              Spacer()
              Button("Add App…") {
                addScopedApplications()
              }
            }
          }

          ForEach(scopedBundleIDs, id: \.self) { bundleID in
            HStack(spacing: 8) {
              ScopedApplicationIcon(bundleID: bundleID, size: 20)
              VStack(alignment: .leading, spacing: 2) {
                Text(ScopedApplication.name(for: bundleID))
                Text(bundleID)
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
              Spacer()
              Button {
                scopedBundleIDs.removeAll { $0 == bundleID }
              } label: {
                Image(systemName: "minus.circle.fill")
                  .foregroundStyle(.secondary)
                  .frame(width: 24, height: 24)
              }
              .buttonStyle(.borderless)
              .help("Remove \(ScopedApplication.name(for: bundleID))")
            }

            if !ScopedApplication.isInstalled(bundleID) {
              Label("This application is not currently installed.", systemImage: "app.dashed")
                .foregroundStyle(.orange)
            }
          }

          if scopedBundleIDs.isEmpty {
            Text("This shortcut works everywhere. Add an app to limit it.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section("Action") {
          Picker("Type", selection: $actionKind) {
            ForEach(ShortcutActionKind.allCases) { kind in
              Text(kind.rawValue).tag(kind)
            }
          }

          actionConfiguration
        }
      }
      .formStyle(.grouped)

      Divider()

      HStack {
        Spacer()
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Button("Save") {
          save()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(!canSave)
      }
      .padding()
    }
    .frame(width: 600)
    .frame(minHeight: 560, maxHeight: 720)
  }

  @ViewBuilder
  private var actionConfiguration: some View {
    switch actionKind {
    case .openApplication:
      LabeledContent("Application") {
        HStack(spacing: 10) {
          ShortcutIconView(action: .openApplication(path: applicationPath), size: 32)
          VStack(alignment: .leading, spacing: 2) {
            Text(applicationName)
            if !applicationPath.isEmpty {
              Text(applicationPath)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
          }
          Spacer()
          Button("Choose…") {
            chooseApplication()
          }
        }
      }

      if !applicationPath.isEmpty && !FileManager.default.fileExists(atPath: applicationPath) {
        Label("This application is not currently installed.", systemImage: "app.dashed")
          .foregroundStyle(.orange)
      }

    case .openURL:
      TextField("URL", text: $urlString, prompt: Text("https://example.com"))

    case .runShortcut:
      TextField(
        "Shortcut name",
        text: $appleShortcutName,
        prompt: Text("Name in Apple Shortcuts")
      )

    case .postKey:
      LabeledContent("Send") {
        ShortcutRecorderView(
          chord: $outputChord,
          displayShortcut: $outputDisplayShortcut
        )
        .frame(width: 190)
      }

    case .transformText:
      Picker("Transformation", selection: $transformationPresetID) {
        ForEach(TextTransformationPreset.all) { preset in
          Text(preset.title).tag(preset.id)
        }
      }

      Text("The selected text is replaced in place. Your clipboard is preserved.")
        .font(.caption)
        .foregroundStyle(.secondary)

    case .pressMenuItem:
      TextField(
        "Menu path",
        text: $menuItemPathText,
        prompt: Text("Message > Archive")
      )

      LabeledContent("Presses") {
        Text(parsedMenuItemPath.isEmpty ? "Nothing yet" : parsedMenuItemPath.joined(separator: " ▸ "))
          .foregroundStyle(parsedMenuItemPath.isEmpty ? .secondary : .primary)
      }

      Text("Separate each menu and submenu with “>”.")
        .font(.caption)
        .foregroundStyle(.secondary)

      if scopedBundleIDs.isEmpty {
        Label(
          "Menu items differ per app. Consider limiting this shortcut to one application.",
          systemImage: "info.circle"
        )
        .foregroundStyle(.orange)
      }

    case .typeText:
      VStack(alignment: .leading, spacing: 8) {
        Text("Text to type")
        TextEditor(text: $customText)
          .font(.body)
          .frame(height: 96)
          .padding(4)
          .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        Text("\(customText.count) characters")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

    case .hideOtherApplications:
      Label("Hide every regular app except InputMate.", systemImage: "eye.slash")

    case .showNotificationCenter:
      Label("Open macOS Notification Center.", systemImage: "bell")

    case .closeNotifications:
      Label("Close visible notifications.", systemImage: "bell.slash")

    case .sleepComputer:
      Label("Put this Mac to sleep immediately.", systemImage: "moon.zzz")
    }
  }

  private var applicationName: String {
    guard !applicationPath.isEmpty else { return "No application selected" }
    return URL(fileURLWithPath: applicationPath).deletingPathExtension().lastPathComponent
  }

  private var isTriggerValid: Bool {
    chord.isConfigured
      && (chord.modifiers != 0 || ShortcutFormatter.isFunctionKey(chord.keyCode))
  }

  private var appScope: ShortcutAppScope? {
    scopedBundleIDs.isEmpty ? nil : ShortcutAppScope(bundleIdentifiers: scopedBundleIDs)
  }

  private var parsedMenuItemPath: [String] {
    menuItemPathText
      .split(separator: ">")
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }

  private var conflict: KeyboardShortcutDefinition? {
    guard isEnabled else { return nil }
    return ShortcutScopePolicy.conflict(
      in: existingDefinitions,
      excludingID: shortcutID,
      chord: chord,
      scope: appScope,
      id: { $0.id },
      isEnabled: { $0.isEnabled },
      chord: { $0.chord },
      scope: { $0.appScope }
    )
  }

  private var coexistingTitles: [String] {
    guard isEnabled else { return [] }
    return ShortcutScopePolicy.coexisting(
      in: existingDefinitions,
      excludingID: shortcutID,
      chord: chord,
      scope: appScope,
      id: { $0.id },
      isEnabled: { $0.isEnabled },
      chord: { $0.chord },
      scope: { $0.appScope }
    )
    .map { "“\($0.actionTitle)”" }
  }

  private var action: ShortcutAction? {
    switch actionKind {
    case .openApplication:
      guard !applicationPath.isEmpty else { return nil }
      return .openApplication(path: applicationPath)
    case .openURL:
      guard
        let url = URL(string: urlString),
        let scheme = url.scheme,
        !scheme.isEmpty
      else { return nil }
      return .openURL(url: url.absoluteString)
    case .runShortcut:
      let name = appleShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { return nil }
      return .runShortcut(name: name)
    case .postKey:
      guard outputChord.isConfigured else { return nil }
      return .postKey(chord: outputChord)
    case .transformText:
      guard TextTransformationPreset.find(transformationPresetID) != nil else { return nil }
      return .transformText(presetID: transformationPresetID)
    case .pressMenuItem:
      let path = parsedMenuItemPath
      guard !path.isEmpty else { return nil }
      return .pressMenuItem(path: path)
    case .typeText:
      guard !customText.isEmpty else { return nil }
      return .typeText(text: customText)
    case .hideOtherApplications:
      return .hideOtherApplications
    case .showNotificationCenter:
      return .showNotificationCenter
    case .closeNotifications:
      return .closeNotifications
    case .sleepComputer:
      return .sleepComputer
    }
  }

  private var canSave: Bool {
    !actionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && isTriggerValid
      && conflict == nil
      && action != nil
  }

  private func chooseApplication() {
    let panel = NSOpenPanel()
    panel.title = "Choose an Application"
    panel.prompt = "Choose"
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false

    guard panel.runModal() == .OK, let url = panel.url else { return }
    let previousName = applicationName
    applicationPath = url.path

    if actionTitle == "New Shortcut" || actionTitle == "Open \(previousName)" {
      actionTitle = "Open \(url.deletingPathExtension().lastPathComponent)"
    }
  }

  private func addScopedApplications() {
    let panel = NSOpenPanel()
    panel.title = "Choose Applications"
    panel.prompt = "Add"
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false

    guard panel.runModal() == .OK else { return }
    for url in panel.urls {
      guard
        let bundleID = Bundle(url: url)?.bundleIdentifier,
        !scopedBundleIDs.contains(bundleID)
      else { continue }
      scopedBundleIDs.append(bundleID)
    }
  }

  private func save() {
    guard let action else { return }
    onSave(
      KeyboardShortcutDefinition(
        id: shortcutID,
        category: action.category,
        chord: chord,
        displayShortcut: ShortcutFormatter.string(for: chord),
        actionTitle: actionTitle.trimmingCharacters(in: .whitespacesAndNewlines),
        action: action,
        isEnabled: isEnabled,
        appScope: appScope
      )
    )
    dismiss()
  }
}
