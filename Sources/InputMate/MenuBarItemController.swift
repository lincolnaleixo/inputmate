import AppKit
import ApplicationServices
import Foundation
import OSLog

/// Presses a menu bar item in another application through the Accessibility API.
///
/// Direct AX access uses the Accessibility grant InputMate already holds and
/// avoids requiring a separate Automation grant for every target application.
final class MenuBarItemController: @unchecked Sendable {
  private let logger = Logger(
    subsystem: "com.robot.InputMate",
    category: "MenuBarItems"
  )

  private static let messagingTimeout: Float = 1.0

  func press(path: [String], processIdentifier: pid_t) {
    guard !path.isEmpty, processIdentifier > 0 else {
      NSSound.beep()
      return
    }

    DispatchQueue.global(qos: .userInitiated).async { [self] in
      do {
        try performPress(path: path, processIdentifier: processIdentifier)
      } catch {
        logger.warning(
          "Menu item press failed: path=\(path.joined(separator: " > "), privacy: .public) reason=\(error.localizedDescription, privacy: .public)"
        )
        NSSound.beep()
      }
    }
  }

  private func performPress(path: [String], processIdentifier: pid_t) throws {
    let application = AXUIElementCreateApplication(processIdentifier)
    AXUIElementSetMessagingTimeout(application, Self.messagingTimeout)

    guard
      let menuBar = copyElement(from: application, attribute: kAXMenuBarAttribute as CFString)
    else {
      throw MenuBarItemError.noMenuBar
    }

    var container = menuBar
    for (index, title) in path.enumerated() {
      guard let children = copyElements(from: container, attribute: kAXChildrenAttribute as CFString)
      else {
        throw MenuBarItemError.noChildren(title)
      }
      let item = try match(title: title, in: children)

      let isFinalSegment = index == path.count - 1
      if isFinalSegment {
        guard isEnabled(item) else {
          throw MenuBarItemError.disabled(title)
        }
        guard AXUIElementPerformAction(item, kAXPressAction as CFString) == .success else {
          throw MenuBarItemError.pressFailed(title)
        }
        return
      }

      guard
        let submenus = copyElements(from: item, attribute: kAXChildrenAttribute as CFString),
        let submenu = submenus.first
      else {
        throw MenuBarItemError.noSubmenu(title)
      }
      container = submenu
    }
  }

  private func match(title: String, in elements: [AXUIElement]) throws -> AXUIElement {
    let titled = elements.compactMap { element -> (AXUIElement, String)? in
      guard let elementTitle = copyString(from: element, attribute: kAXTitleAttribute as CFString)
      else { return nil }
      return (element, elementTitle)
    }

    let target = title.trimmingCharacters(in: .whitespaces)

    if let exact = titled.first(where: { $0.1 == title }) {
      return exact.0
    }

    let caseInsensitive = titled.filter {
      $0.1.trimmingCharacters(in: .whitespaces)
        .compare(target, options: .caseInsensitive) == .orderedSame
    }
    if caseInsensitive.count == 1 {
      return caseInsensitive[0].0
    }
    guard caseInsensitive.isEmpty else {
      throw MenuBarItemError.ambiguous(title)
    }

    let prefixed = titled.filter {
      $0.1.trimmingCharacters(in: .whitespaces)
        .lowercased()
        .hasPrefix(target.lowercased())
    }
    if prefixed.count == 1 {
      return prefixed[0].0
    }
    throw prefixed.isEmpty
      ? MenuBarItemError.notFound(title)
      : MenuBarItemError.ambiguous(title)
  }

  private func isEnabled(_ element: AXUIElement) -> Bool {
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value) == .success
    else { return true }
    return (value as? Bool) ?? true
  }

  private func copyElement(from element: AXUIElement, attribute: CFString) -> AXUIElement? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
      let value,
      CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    return (value as! AXUIElement)
  }

  private func copyElements(from element: AXUIElement, attribute: CFString) -> [AXUIElement]? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(element, attribute, &value) == .success,
      let elements = value as? [AXUIElement]
    else { return nil }
    return elements
  }

  private func copyString(from element: AXUIElement, attribute: CFString) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else {
      return nil
    }
    return value as? String
  }
}

private enum MenuBarItemError: LocalizedError {
  case noMenuBar
  case noChildren(String)
  case noSubmenu(String)
  case notFound(String)
  case ambiguous(String)
  case disabled(String)
  case pressFailed(String)

  var errorDescription: String? {
    switch self {
    case .noMenuBar:
      "the frontmost application exposes no menu bar"
    case .noChildren(let title):
      "no menu items while looking for “\(title)”"
    case .noSubmenu(let title):
      "“\(title)” has no submenu"
    case .notFound(let title):
      "no menu item titled “\(title)”"
    case .ambiguous(let title):
      "more than one menu item matches “\(title)”"
    case .disabled(let title):
      "“\(title)” is disabled right now"
    case .pressFailed(let title):
      "pressing “\(title)” was refused"
    }
  }
}
