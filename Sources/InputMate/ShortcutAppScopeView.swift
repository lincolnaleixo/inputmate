import AppKit
import InputMateCore
import SwiftUI

enum ScopedApplication {
  static func url(for bundleID: String) -> URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
  }

  static func name(for bundleID: String) -> String {
    guard let url = url(for: bundleID) else { return bundleID }
    return url.deletingPathExtension().lastPathComponent
  }

  static func icon(for bundleID: String) -> NSImage? {
    guard let url = url(for: bundleID) else { return nil }
    return NSWorkspace.shared.icon(forFile: url.path)
  }

  static func isInstalled(_ bundleID: String) -> Bool {
    url(for: bundleID) != nil
  }

  static func summary(for scope: ShortcutAppScope?) -> String {
    guard let scope, !scope.isGlobal else { return "All applications" }
    if scope.bundleIdentifiers.count == 1 {
      return name(for: scope.bundleIdentifiers[0])
    }
    return scope.bundleIdentifiers.map { name(for: $0) }.joined(separator: ", ")
  }
}

struct ScopedApplicationIcon: View {
  let bundleID: String
  var size: CGFloat = 20

  var body: some View {
    Group {
      if let icon = ScopedApplication.icon(for: bundleID) {
        Image(nsImage: icon)
          .resizable()
          .interpolation(.high)
      } else {
        Image(systemName: "app.dashed")
          .resizable()
          .scaledToFit()
          .foregroundStyle(.orange)
      }
    }
    .frame(width: size, height: size)
  }
}

struct ShortcutScopeSummaryView: View {
  let scope: ShortcutAppScope?

  private static let maximumVisibleIcons = 3

  var body: some View {
    let identifiers = scope?.bundleIdentifiers ?? []

    if identifiers.isEmpty {
      Text("All apps")
        .foregroundStyle(.secondary)
    } else if identifiers.count == 1 {
      HStack(spacing: 8) {
        ScopedApplicationIcon(bundleID: identifiers[0], size: 20)
        Text(ScopedApplication.name(for: identifiers[0]))
          .lineLimit(1)
      }
      .help(ScopedApplication.summary(for: scope))
    } else {
      HStack(spacing: 8) {
        HStack(spacing: 4) {
          ForEach(identifiers.prefix(Self.maximumVisibleIcons), id: \.self) { bundleID in
            ScopedApplicationIcon(bundleID: bundleID, size: 20)
          }
        }
        Text("\(identifiers.count) apps")
          .lineLimit(1)
      }
      .help(ScopedApplication.summary(for: scope))
    }
  }
}
