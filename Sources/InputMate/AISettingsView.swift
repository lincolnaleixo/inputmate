import InputMateCore
import SwiftUI

struct AISettingsView: View {
  @ObservedObject var model: AppModel

  @State private var apiKey = ""
  @State private var modelID = ""
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
            systemImage: model.isActivelyHandlingInput
              ? "waveform.path" : "waveform.path.badge.minus"
          )
          .foregroundStyle(model.isActivelyHandlingInput ? .green : .orange)
        }
      }

      Section("Text Transformations") {
        Picker(
          "Provider",
          selection: Binding(
            get: { model.textTransformationProvider },
            set: { provider in
              model.setTextTransformationProvider(provider)
              modelID = model.textTransformationModel
              apiKey = ""
              feedback = nil
            }
          )
        ) {
          ForEach(AIProvider.allCases) { provider in
            Text(provider.displayName).tag(provider)
          }
        }

        TextField("Model", text: $modelID)
          .onSubmit { saveModel() }

        HStack {
          Button("Save Model", action: saveModel)
            .disabled(modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          Menu("Suggested Models") {
            ForEach(model.textTransformationProvider.suggestedModels, id: \.self) {
              suggestedModel in
              Button(suggestedModel) {
                modelID = suggestedModel
                saveModel()
              }
            }
          }

          Button("Use Default") {
            model.resetTextTransformationModel()
            modelID = model.textTransformationModel
            feedback =
              "Using the default model for \(model.textTransformationProvider.displayName)."
          }
        }

        HStack {
          Label(
            model.hasTextTransformationAPIKey
              ? "\(model.textTransformationProvider.displayName) API key stored in Keychain"
              : "\(model.textTransformationProvider.displayName) API key required",
            systemImage: model.hasTextTransformationAPIKey ? "checkmark.shield.fill" : "key"
          )
          .foregroundStyle(model.hasTextTransformationAPIKey ? .green : .orange)
          Spacer()
        }

        SecureField(
          model.hasTextTransformationAPIKey
            ? "Replace API key"
            : "\(model.textTransformationProvider.displayName) API key",
          text: $apiKey
        )

        HStack {
          Button("Save to Keychain") {
            if model.saveTextTransformationAPIKey(apiKey) {
              apiKey = ""
              feedback = "Saved securely in Keychain."
            } else {
              feedback = model.statusMessage
            }
          }
          .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

          if model.hasTextTransformationAPIKey {
            Button("Remove Key", role: .destructive) {
              model.removeTextTransformationAPIKey()
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
          "When you invoke a text transformation, the selected text is sent to \(model.textTransformationProvider.displayName) using \(model.textTransformationModel) and replaced with the response. InputMate preserves your existing clipboard contents."
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
    .frame(minWidth: 560, minHeight: 520)
    .onAppear {
      modelID = model.textTransformationModel
    }
    .sheet(item: $editorContext) { context in
      ShortcutEditorView(
        definition: context.definition,
        existingDefinitions: model.shortcutDefinitions,
        onSave: model.saveShortcut
      )
    }
  }

  private func saveModel() {
    if model.saveTextTransformationModel(modelID) {
      modelID = model.textTransformationModel
      feedback = "Model saved for \(model.textTransformationProvider.displayName)."
    } else {
      feedback = model.statusMessage
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
