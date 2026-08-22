import InputMateCore

enum ShortcutFormatter {
  static func string(for chord: ShortcutChord) -> String {
    guard chord.isConfigured else { return "Not set" }

    let side = sideLabel(for: chord)
    let symbols = modifierSymbols(for: chord)
    let modifiers = [side, symbols].filter { !$0.isEmpty }.joined(separator: " ")
    let key = keyName(for: chord.keyCode)
    return [modifiers, key].filter { !$0.isEmpty }.joined(separator: " ")
  }

  static func keyName(for keyCode: Int64) -> String {
    keyNames[keyCode] ?? "Key \(keyCode)"
  }

  static func isFunctionKey(_ keyCode: Int64) -> Bool {
    ShortcutChord.isFunctionKey(keyCode)
  }

  private static func sideLabel(for chord: ShortcutChord) -> String {
    var hasLeft = false
    var hasRight = false

    if chord.modifiers & ShortcutChord.shift != 0 {
      hasLeft = hasLeft || chord.deviceFlags & ShortcutChord.leftShift != 0
      hasRight = hasRight || chord.deviceFlags & ShortcutChord.rightShift != 0
    }
    if chord.modifiers & ShortcutChord.control != 0 {
      hasLeft = hasLeft || chord.deviceFlags & ShortcutChord.leftControl != 0
      hasRight = hasRight || chord.deviceFlags & ShortcutChord.rightControl != 0
    }
    if chord.modifiers & ShortcutChord.option != 0 {
      hasLeft = hasLeft || chord.deviceFlags & ShortcutChord.leftOption != 0
      hasRight = hasRight || chord.deviceFlags & ShortcutChord.rightOption != 0
    }
    if chord.modifiers & ShortcutChord.command != 0 {
      hasLeft = hasLeft || chord.deviceFlags & ShortcutChord.leftCommand != 0
      hasRight = hasRight || chord.deviceFlags & ShortcutChord.rightCommand != 0
    }

    if hasLeft && !hasRight { return "Left" }
    if hasRight && !hasLeft { return "Right" }
    return ""
  }

  private static func modifierSymbols(for chord: ShortcutChord) -> String {
    var value = ""
    if chord.modifiers & ShortcutChord.shift != 0 { value += "⇧" }
    if chord.modifiers & ShortcutChord.control != 0 { value += "⌃" }
    if chord.modifiers & ShortcutChord.option != 0 { value += "⌥" }
    if chord.modifiers & ShortcutChord.command != 0 { value += "⌘" }
    if chord.modifiers & ShortcutChord.function != 0 && !isFunctionKey(chord.keyCode) {
      value += "Fn"
    }
    return value
  }

  private static let keyNames: [Int64: String] = [
    0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
    8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
    16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
    23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
    30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "Return",
    37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
    44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
    50: "`", 51: "Delete", 53: "Escape", 96: "F5", 97: "F6", 98: "F7",
    99: "F3", 100: "F8", 101: "F9", 103: "F11", 109: "F10", 111: "F12",
    118: "F4", 120: "F2", 122: "F1",
    ShortcutChord.brightnessUpKeyCode: "Brightness Up",
    ShortcutChord.brightnessDownKeyCode: "Brightness Down",
  ]
}
