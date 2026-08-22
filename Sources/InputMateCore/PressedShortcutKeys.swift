public struct PressedShortcutKeys: Sendable {
  private var keyCodes: Set<Int64> = []

  public init() {}

  public mutating func begin(keyCode: Int64) -> Bool {
    keyCodes.insert(keyCode).inserted
  }

  public mutating func end(candidateKeyCodes: [Int64]) -> Int64? {
    guard let keyCode = candidateKeyCodes.first(where: keyCodes.contains) else {
      return nil
    }
    keyCodes.remove(keyCode)
    return keyCode
  }

  public mutating func endAll(candidateKeyCodes: [Int64]) {
    keyCodes.subtract(candidateKeyCodes)
  }

  public mutating func reset() {
    keyCodes.removeAll()
  }
}
