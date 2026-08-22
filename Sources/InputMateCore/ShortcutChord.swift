public struct ShortcutChord: Codable, Equatable, Sendable {
  public static let brightnessUpKeyCode: Int64 = 1002
  public static let brightnessDownKeyCode: Int64 = 1003

  private static let missionControlKeyCode: Int64 = 0xA0
  private static let f1KeyCode: Int64 = 122
  private static let f2KeyCode: Int64 = 120
  private static let f3KeyCode: Int64 = 99

  public static let shift: UInt64 = 0x0002_0000
  public static let control: UInt64 = 0x0004_0000
  public static let option: UInt64 = 0x0008_0000
  public static let command: UInt64 = 0x0010_0000
  public static let function: UInt64 = 0x0080_0000

  public static let leftControl: UInt64 = 0x01
  public static let leftShift: UInt64 = 0x02
  public static let rightShift: UInt64 = 0x04
  public static let leftCommand: UInt64 = 0x08
  public static let rightCommand: UInt64 = 0x10
  public static let leftOption: UInt64 = 0x20
  public static let rightOption: UInt64 = 0x40
  public static let rightControl: UInt64 = 0x2000

  public static let leftHyperModifiers = shift | control | option | command
  public static let leftHyperDeviceFlags =
    leftShift | leftControl | leftOption | leftCommand

  public static let independentModifierMask =
    shift | control | option | command | function
  public static let deviceSideMask: UInt64 = 0x207F

  private static let functionKeyCodes: Set<Int64> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111,
  ]

  public let keyCode: Int64
  public let modifiers: UInt64
  public let deviceFlags: UInt64

  public init(keyCode: Int64, modifiers: UInt64, deviceFlags: UInt64) {
    self.keyCode = keyCode
    self.modifiers = modifiers
    self.deviceFlags = deviceFlags
  }

  public static func capturing(keyCode: Int64, flags: UInt64) -> ShortcutChord {
    let keyCode = canonicalKeyCode(keyCode)
    return ShortcutChord(
      keyCode: keyCode,
      modifiers: normalizedModifiers(keyCode: keyCode, flags: flags),
      deviceFlags: flags & deviceSideMask
    )
  }

  public static func isFunctionKey(_ keyCode: Int64) -> Bool {
    functionKeyCodes.contains(canonicalKeyCode(keyCode))
  }

  public static func canonicalKeyCode(_ keyCode: Int64) -> Int64 {
    switch keyCode {
    case missionControlKeyCode:
      f3KeyCode
    default:
      keyCode
    }
  }

  public static func topRowFunctionKeyCode(systemDefinedData1: Int64) -> Int64? {
    let rawValue = UInt64(UInt32(truncatingIfNeeded: systemDefinedData1))
    let systemKeyType = (rawValue & 0xFFFF_0000) >> 16
    return switch systemKeyType {
    case 3:
      f1KeyCode
    case 2:
      f2KeyCode
    default:
      nil
    }
  }

  public static func mediaKeyCode(systemDefinedData1: Int64) -> Int64? {
    let rawValue = UInt64(UInt32(truncatingIfNeeded: systemDefinedData1))
    let systemKeyType = (rawValue & 0xFFFF_0000) >> 16
    return switch systemKeyType {
    case 2:
      brightnessUpKeyCode
    case 3:
      brightnessDownKeyCode
    default:
      nil
    }
  }

  public static func isSystemDefinedKeyDown(data1: Int64) -> Bool {
    let rawValue = UInt64(UInt32(truncatingIfNeeded: data1))
    return (rawValue & 0x0000_FF00) >> 8 == 0x0A
  }

  public static func isSystemDefinedKeyUp(data1: Int64) -> Bool {
    let rawValue = UInt64(UInt32(truncatingIfNeeded: data1))
    return (rawValue & 0x0000_FF00) >> 8 == 0x0B
  }

  public var isConfigured: Bool {
    keyCode >= 0
  }

  public static func == (lhs: ShortcutChord, rhs: ShortcutChord) -> Bool {
    let lhsKeyCode = canonicalKeyCode(lhs.keyCode)
    let rhsKeyCode = canonicalKeyCode(rhs.keyCode)
    return lhsKeyCode == rhsKeyCode
      && normalizedModifiers(keyCode: lhsKeyCode, flags: lhs.modifiers)
        == normalizedModifiers(keyCode: rhsKeyCode, flags: rhs.modifiers)
      && lhs.deviceFlags == rhs.deviceFlags
  }

  public func matches(keyCode: Int64, flags: UInt64) -> Bool {
    let configuredKeyCode = Self.canonicalKeyCode(self.keyCode)
    let eventKeyCode = Self.canonicalKeyCode(keyCode)
    guard configuredKeyCode == eventKeyCode else { return false }
    let configuredModifiers = Self.normalizedModifiers(
      keyCode: configuredKeyCode,
      flags: modifiers
    )
    let eventModifiers = Self.normalizedModifiers(keyCode: eventKeyCode, flags: flags)
    let eventDeviceFlags = flags & Self.deviceSideMask
    return eventModifiers == configuredModifiers && eventDeviceFlags == deviceFlags
  }

  public static func withFallbackDeviceFlags(
    eventFlags: UInt64,
    sessionFlags: UInt64
  ) -> UInt64 {
    var flags = eventFlags
    if flags & independentModifierMask == 0 {
      flags |= sessionFlags & independentModifierMask
    }
    if flags & deviceSideMask == 0 {
      flags |= sessionFlags & deviceSideMask
    }
    return flags
  }

  private static func normalizedModifiers(keyCode: Int64, flags: UInt64) -> UInt64 {
    var modifiers = flags & independentModifierMask
    if isFunctionKey(keyCode) {
      modifiers &= ~function
    }
    return modifiers
  }
}

public enum ShortcutPreferencePolicy {
  public static let currentMigrationVersion = 1
  public static let legacyLeftHyperTChord = ShortcutChord(
    keyCode: 17,
    modifiers: ShortcutChord.leftHyperModifiers,
    deviceFlags: ShortcutChord.leftHyperDeviceFlags
  )

  public static func sanitizedDefaults<Element>(
    from definitions: [Element],
    chord: (Element) -> ShortcutChord
  ) -> [Element] {
    definitions.filter { chord($0) != legacyLeftHyperTChord }
  }

  public static func migrate<Element>(
    _ definitions: [Element],
    fromVersion: Int,
    chord: (Element) -> ShortcutChord
  ) -> (definitions: [Element], version: Int, didMigrate: Bool) {
    let migratedDefinitions = sanitizedDefaults(from: definitions, chord: chord)
    let migratedVersion = max(fromVersion, currentMigrationVersion)
    return (
      migratedDefinitions,
      migratedVersion,
      fromVersion < currentMigrationVersion || migratedDefinitions.count != definitions.count
    )
  }
}
