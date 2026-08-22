import SwiftUI

struct AISettingsView: View {
  @ObservedObject var model: AppModel

  @State private var apiKey = ""
  @State private var feedback: String?
  @State private var editorContext: ShortcutEditorContext?

  var body: some View {
    Form {
      Section("InputMate") {
        LabeledContent("Accessibility") {
          Label(
            model.hasAccessibilityAccess ? "Granted" : "Required",
            systemImage: model.hasAccessibilityAccess
              ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
          )
          .foregroundStyle(model.hasAccessibilityAccess ? .green : .orange)
        }

        LabeledContent("Global input capture") {
          Label(
            model.isActivelyHandlingInput ? "Active" : "Inactive",
            systemImage: model.isActivelyHandlingInput ? "waveform.path" : "waveform.path.badge.minus"
          )
          .foregroundStyle(model.isActivelyHandlingInput ? .green : .orange)
        }
      }

      Section("Text Transformations") {
        LabeledContent("Provider", value: "Cerebras")
        LabeledContent("Model", value: "gemma-4-31b")

        HStack {
          Label(
            model.hasCerebrasAPIKey ? "API key stored in Keychain" : "API key required",
            systemImage: model.hasCerebrasAPIKey ? "checkmark.shield.fill" : "key"
          )
          .foregroundStyle(model.hasCerebrasAPIKey ? .green : .orange)
          Spacer()
        }

        SecureField(
          model.hasCerebrasAPIKey ? "Replace API key" : "Cerebras API key",
          text: $apiKey
        )

        HStack {
          Button("Save to Keychain") {
            if model.saveCerebrasAPIKey(apiKey) {
              apiKey = ""
              feedback = "Saved securely in Keychain."
            } else {
              feedback = model.statusMessage
            }
          }
          .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if model.hasCerebrasAPIKey {
            Button("Remove Key", role: .destructive) {
              model.removeCerebrasAPIKey()
              feedback = model.statusMessage
            }
          }
        }

        if let feedback {
          Text(feedback)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Section("Privacy") {
        Text(
          "When you invoke a text transformation, the selected text is sent to Cerebras and replaced with the response. InputMate preserves your existing clipboard contents."
        )
        .foregroundStyle(.secondary)
      }

      Section("Text Transformation Shortcuts") {
        ForEach(transformationShortcuts) { shortcut in
          LabeledContent {
            Button {
              editorContext = ShortcutEditorContext(definition: shortcut)
            } label: {
              HStack(spacing: 7) {
                Text(shortcut.displayShortcut)
                  .font(.system(.body, design: .monospaced))
                Image(systemName: "pencil")
                  .font(.caption2)
              }
            }
            .help("Change \(shortcut.actionTitle) shortcut")
          } label: {
            HStack(spacing: 9) {
              ShortcutIconView(action: shortcut.action, size: 22)
              Text(shortcut.actionTitle)
            }
          }
        }

        Text("Click a shortcut to record a different key combination.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
    .frame(minWidth: 520, minHeight: 430)
    .sheet(item: $editorContext) { context in
      ShortcutEditorView(
        definition: context.definition,
        existingDefinitions: model.shortcutDefinitions,
        onSave: model.saveShortcut
      )
    }
  }

  private var transformationShortcuts: [KeyboardShortcutDefinition] {
    [
      TextTransformationPreset.spanishID,
      TextTransformationPreset.englishID,
      TextTransformationPreset.improveID,
    ].compactMap { id in
      model.shortcutDefinitions.first(where: { $0.id == id })
    }
  }
}
