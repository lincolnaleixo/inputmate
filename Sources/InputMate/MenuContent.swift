import AppKit
import SwiftUI

struct MenuContent: View {
  @Environment(\.openWindow) private var openWindow
  @ObservedObject var model: AppModel

  var body: some View {
    Toggle(
      "Reverse Mouse Wheel",
      isOn: Binding(
        get: { model.reversesMouseWheel },
        set: { model.setReversesMouseWheel($0) }
      )
    )
    .keyboardShortcut("r", modifiers: [.command, .option])

    Toggle(
      "Keyboard Shortcuts",
      isOn: Binding(
        get: { model.handlesKeyboardShortcuts },
        set: { model.setHandlesKeyboardShortcuts($0) }
      )
    )
    .keyboardShortcut("k", modifiers: [.command, .option])

    if model.isActivelyHandlingInput {
      if model.reversesMouseWheel {
        Label("Mouse: traditional · Trackpad: natural", systemImage: "computermouse")
      }
      if model.handlesKeyboardShortcuts {
        Label(
          "\(model.enabledShortcutCount) keyboard shortcuts active",
          systemImage: "keyboard"
        )
      }
    } else if model.requiresAccessibility && !model.hasAccessibilityAccess {
      Label("Accessibility access required", systemImage: "exclamationmark.triangle.fill")

      Button("Grant Accessibility Access…") {
        model.requestAccessibilityAccess()
      }

      Button("Open Accessibility Settings…") {
        model.openAccessibilitySettings()
      }
      .keyboardShortcut(",", modifiers: [.command, .shift])
    }

    if let statusMessage = model.statusMessage {
      Text(statusMessage)
    }

    Divider()

    Button("Manage Shortcuts…") {
      NSApplication.shared.activate(ignoringOtherApps: true)
      openWindow(id: "shortcuts")
    }
    .keyboardShortcut("/", modifiers: .command)

    Button("Text Transformation Settings…") {
      NSApplication.shared.activate(ignoringOtherApps: true)
      openWindow(id: "settings")
    }
    .keyboardShortcut(",", modifiers: .command)

    if !model.hasCerebrasAPIKey {
      Label("Cerebras API key required", systemImage: "key")
    }

    Toggle(
      "Open at Login",
      isOn: Binding(
        get: { model.opensAtLogin },
        set: { model.setOpensAtLogin($0) }
      )
    )

    if model.reversesMouseWheel {
      Text("Keep Natural scrolling enabled in macOS.")
    }

    Divider()

    Button("Quit InputMate") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q", modifiers: .command)
  }
}
