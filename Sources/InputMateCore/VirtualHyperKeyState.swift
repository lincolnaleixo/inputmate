public struct VirtualHyperKeyState: Sendable {
  public static let keyCode: Int64 = 79

  public private(set) var isActive = false

  public init() {}

  @discardableResult
  public mutating func handle(
    keyCode: Int64,
    isKeyDown: Bool,
    isKeyUp: Bool
  ) -> Bool {
    guard keyCode == Self.keyCode, isKeyDown || isKeyUp else { return false }
    isActive = isKeyDown
    return true
  }

  public func augmenting(_ flags: UInt64) -> UInt64 {
    guard isActive else { return flags }
    return flags
      | ShortcutChord.leftHyperModifiers
      | ShortcutChord.leftHyperDeviceFlags
  }

  public mutating func reset() {
    isActive = false
  }
}
