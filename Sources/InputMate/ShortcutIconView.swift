import AppKit
import SwiftUI

struct ShortcutIconView: View {
  let action: ShortcutAction
  var size: CGFloat = 26

  var body: some View {
    Group {
      if case .openApplication(let path) = action,
        FileManager.default.fileExists(atPath: path)
      {
        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
          .resizable()
          .interpolation(.high)
      } else {
        Image(systemName: symbolName)
          .resizable()
          .scaledToFit()
          .padding(3)
          .foregroundStyle(symbolColor)
      }
    }
    .frame(width: size, height: size)
    .help(helpText)
  }

  private var symbolName: String {
    switch action {
    case .openApplication:
      "questionmark.app.dashed"
    case .openURL:
      "globe"
    case .runShortcut:
      "square.stack.3d.up"
    case .postKey:
      "keyboard"
    case .transformText:
      "wand.and.stars"
    case .pressMenuItem:
      "menubar.arrow.up.rectangle"
    case .typeText:
      "text.insert"
    case .hideOtherApplications:
      "eye.slash"
    case .showNotificationCenter:
      "bell"
    case .closeNotifications:
      "bell.slash"
    case .sleepComputer:
      "moon.zzz"
    }
  }

  private var symbolColor: Color {
    if case .openApplication = action { return .orange }
    return .accentColor
  }

  private var helpText: String {
    if case .openApplication(let path) = action {
      return FileManager.default.fileExists(atPath: path)
        ? URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
        : "Application not installed"
    }
    return action.kind.rawValue
  }
}
