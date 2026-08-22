import SwiftUI

@main
@MainActor
struct InputMateApp: App {
  @StateObject private var model = AppModel()
  private let updateController = UpdateController()

  var body: some Scene {
    MenuBarExtra {
      MenuContent(
        model: model,
        updater: updateController.updater
      )
    } label: {
      Image(systemName: model.menuBarSymbol)
        .accessibilityLabel("InputMate")
    }
    .menuBarExtraStyle(.menu)
    .commands {
      CommandGroup(replacing: .appTermination) {
        Button("Quit InputMate") {
          NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
      }
    }

    Window("InputMate Shortcuts", id: "shortcuts") {
      ShortcutReferenceView(model: model)
    }
    .defaultSize(width: 980, height: 640)
    .defaultPosition(.center)

    Window("InputMate Settings", id: "settings") {
      AISettingsView(model: model)
    }
    .defaultSize(width: 560, height: 480)
    .defaultPosition(.center)
  }
}
