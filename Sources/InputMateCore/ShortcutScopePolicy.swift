/// The set of applications a shortcut is limited to.
///
/// An absent scope, or one with no bundle identifiers, means the shortcut is
/// global and fires in every application.
public struct ShortcutAppScope: Codable, Equatable, Sendable {
  public var bundleIdentifiers: [String]

  public init(bundleIdentifiers: [String] = []) {
    self.bundleIdentifiers = bundleIdentifiers
  }

  public var isGlobal: Bool {
    bundleIdentifiers.isEmpty
  }
}

public enum ShortcutScopePolicy {
  public static func appliesTo(scope: ShortcutAppScope?, frontmostBundleID: String?) -> Bool {
    guard let scope, !scope.isGlobal else { return true }
    guard let frontmostBundleID else { return false }
    return scope.bundleIdentifiers.contains {
      $0.compare(frontmostBundleID, options: .caseInsensitive) == .orderedSame
    }
  }

  public static func scopesIntersect(_ lhs: ShortcutAppScope?, _ rhs: ShortcutAppScope?) -> Bool {
    guard let lhs, !lhs.isGlobal, let rhs, !rhs.isGlobal else { return true }
    let rightIdentifiers = rhs.bundleIdentifiers.map { $0.lowercased() }
    return lhs.bundleIdentifiers.contains { rightIdentifiers.contains($0.lowercased()) }
  }

  public static func select<Element>(
    from elements: [Element],
    frontmostBundleID: String?,
    isEnabled: (Element) -> Bool,
    matchesChord: (Element) -> Bool,
    scope: (Element) -> ShortcutAppScope?
  ) -> Element? {
    var globalMatch: Element?

    for element in elements where isEnabled(element) && matchesChord(element) {
      let elementScope = scope(element)
      if let elementScope, !elementScope.isGlobal {
        if appliesTo(scope: elementScope, frontmostBundleID: frontmostBundleID) {
          return element
        }
      } else if globalMatch == nil {
        globalMatch = element
      }
    }
    return globalMatch
  }

  public static func conflict<Element>(
    in elements: [Element],
    excludingID candidateID: String,
    chord candidateChord: ShortcutChord,
    scope candidateScope: ShortcutAppScope?,
    id: (Element) -> String,
    isEnabled: (Element) -> Bool,
    chord: (Element) -> ShortcutChord,
    scope: (Element) -> ShortcutAppScope?
  ) -> Element? {
    elements.first {
      id($0) != candidateID
        && isEnabled($0)
        && chord($0) == candidateChord
        && scopesIntersect(scope($0), candidateScope)
    }
  }

  public static func coexisting<Element>(
    in elements: [Element],
    excludingID candidateID: String,
    chord candidateChord: ShortcutChord,
    scope candidateScope: ShortcutAppScope?,
    id: (Element) -> String,
    isEnabled: (Element) -> Bool,
    chord: (Element) -> ShortcutChord,
    scope: (Element) -> ShortcutAppScope?
  ) -> [Element] {
    elements.filter {
      id($0) != candidateID
        && isEnabled($0)
        && chord($0) == candidateChord
        && !scopesIntersect(scope($0), candidateScope)
    }
  }
}
