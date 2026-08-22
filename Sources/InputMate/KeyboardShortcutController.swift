import AppKit
import CoreGraphics
import InputMateCore
import OSLog

final class KeyboardShortcutController: @unchecked Sendable {
  private let stateLock = NSLock()
  private var definitions = KeyboardShortcutCatalog.definitions
  private var pressedMediaKeys = PressedShortcutKeys()
  private var lastModifierFlags: UInt64 = 0
  private var virtualHyperKey = VirtualHyperKeyState()
  private let textTransformations = TextTransformationController()
  private let frontmostApplication = FrontmostApplicationTracker()
  private let menuBarItems = MenuBarItemController()
  @MainActor private let modifierRelease = ModifierReleaseWaiter()
  private let logger = Logger(
    subsystem: "com.robot.InputMate",
    category: "KeyboardShortcuts"
  )

  func update(definitions: [KeyboardShortcutDefinition]) {
    stateLock.withLock {
      self.definitions = definitions
    }
  }

  func handleModifierFlagsChanged(flags: UInt64) {
    let hyperStateChanged = stateLock.withLock {
      let wasHyperActive =
        lastModifierFlags & ShortcutChord.leftHyperModifiers
        == ShortcutChord.leftHyperModifiers
      let isHyperActive =
        flags & ShortcutChord.leftHyperModifiers
        == ShortcutChord.leftHyperModifiers
      lastModifierFlags = flags
      if !isHyperActive {
        pressedMediaKeys.endAll(candidateKeyCodes: [122, 120])
      }
      return wasHyperActive != isHyperActive
    }
    if hyperStateChanged {
      logger.info(
        "Left Hyper state changed: active=\(flags & ShortcutChord.leftHyperModifiers == ShortcutChord.leftHyperModifiers, privacy: .public) flags=\(flags, privacy: .public)"
      )
    }
    textTransformations.modifierFlagsChanged(flags: flags)
    Task { @MainActor [weak self] in
      self?.modifierRelease.modifierFlagsChanged(flags: flags)
    }
  }

  func resetTransientState() {
    stateLock.withLock {
      pressedMediaKeys.reset()
      lastModifierFlags = 0
      virtualHyperKey.reset()
    }
  }

  func handle(event: CGEvent, type: CGEventType) -> Bool {
    guard
      event.getIntegerValueField(.eventSourceUserData) != Self.syntheticEventMarker
    else {
      return false
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let virtualHyperTransition = stateLock.withLock {
      let wasActive = virtualHyperKey.isActive
      let consumed = virtualHyperKey.handle(
        keyCode: keyCode,
        isKeyDown: type == .keyDown,
        isKeyUp: type == .keyUp
      )
      if consumed, !virtualHyperKey.isActive {
        pressedMediaKeys.endAll(candidateKeyCodes: [122, 120])
      }
      return consumed ? (wasActive, virtualHyperKey.isActive) : nil
    }
    if let virtualHyperTransition {
      if virtualHyperTransition.0 != virtualHyperTransition.1 {
        logger.info(
          "InputMate Hyper state changed: active=\(virtualHyperTransition.1, privacy: .public)"
        )
      }
      return true
    }

    guard type == .keyDown else { return false }
    let (flags, shortcut) = stateLock.withLock {
      let flags = effectiveFlags(event.flags.rawValue)
      return (flags, matchingShortcut(keyCode: keyCode, flags: flags))
    }
    guard let shortcut else {
      logUnmatchedTransformationCandidate(keyCode: keyCode, flags: flags)
      return false
    }

    if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
      perform(shortcut.action)
    }
    return true
  }

  func handleSystemDefined(event: CGEvent) -> Bool {
    guard
      event.getIntegerValueField(.eventSourceUserData) != Self.syntheticEventMarker,
      let nsEvent = NSEvent(cgEvent: event)
    else {
      return false
    }

    let data1 = Int64(nsEvent.data1)
    let candidateKeyCodes = systemDefinedCandidateKeyCodes(data1: data1)

    if ShortcutChord.isSystemDefinedKeyUp(data1: data1) {
      return stateLock.withLock {
        pressedMediaKeys.end(candidateKeyCodes: candidateKeyCodes) != nil
      }
    }
    guard ShortcutChord.isSystemDefinedKeyDown(data1: data1) else {
      return false
    }

    let rawFlags = event.flags.rawValue
    let sessionFlags = CGEventSource.flagsState(.combinedSessionState).rawValue
    let (flags, cachedFlags, match) = stateLock.withLock {
      let flags = effectiveFlags(rawFlags, sessionFlags: sessionFlags)
      return (
        flags,
        lastModifierFlags,
        matchingSystemDefinedShortcut(data1: data1, flags: flags)
      )
    }
    if candidateKeyCodes.contains(where: { $0 == 122 || $0 == 120 }) {
      logger.info(
        "Top-row system event: rawFlags=\(rawFlags, privacy: .public) sessionFlags=\(sessionFlags, privacy: .public) cachedFlags=\(cachedFlags, privacy: .public) effectiveFlags=\(flags, privacy: .public)"
      )
    }
    guard let (keyCode, shortcut) = match else {
      if let keyCode = ShortcutChord.topRowFunctionKeyCode(systemDefinedData1: data1) {
        logUnmatchedTransformationCandidate(keyCode: keyCode, flags: flags)
      }
      return false
    }

    let shouldPerform = stateLock.withLock {
      pressedMediaKeys.begin(keyCode: keyCode)
    }
    if shouldPerform {
      perform(shortcut.action)
    }
    return true
  }

  private func perform(_ action: ShortcutAction) {
    switch action {
    case .openApplication(let path):
      openApplication(path: path)
    case .openURL(let url):
      openURL(url)
    case .runShortcut(let name):
      launch(executable: "/usr/bin/shortcuts", arguments: ["run", name])
    case .postKey(let chord):
      postKey(chord: chord)
    case .transformText(let presetID):
      textTransformations.transform(presetID: presetID)
    case .pressMenuItem(let path):
      menuBarItems.press(
        path: path,
        processIdentifier: frontmostApplication.processIdentifier
      )
    case .typeText(let text):
      typeText(text)
    case .hideOtherApplications:
      hideOtherApplications()
    case .showNotificationCenter:
      runAppleScript(Self.showNotificationCenterScript)
    case .closeNotifications:
      runAppleScript(Self.closeNotificationsScript)
    case .sleepComputer:
      runAppleScript("tell application \"System Events\" to sleep")
    }
  }

  private func matchingShortcut(keyCode: Int64, flags: UInt64) -> KeyboardShortcutDefinition? {
    ShortcutScopePolicy.select(
      from: definitions,
      frontmostBundleID: frontmostApplication.bundleIdentifier,
      isEnabled: { $0.isEnabled },
      matchesChord: { $0.chord.matches(keyCode: keyCode, flags: flags) },
      scope: { $0.appScope }
    )
  }

  private func matchingSystemDefinedShortcut(
    data1: Int64,
    flags: UInt64
  ) -> (Int64, KeyboardShortcutDefinition)? {
    for keyCode in systemDefinedCandidateKeyCodes(data1: data1) {
      if let shortcut = matchingShortcut(keyCode: keyCode, flags: flags) {
        return (keyCode, shortcut)
      }
    }
    return nil
  }

  private func systemDefinedCandidateKeyCodes(data1: Int64) -> [Int64] {
    [
      ShortcutChord.topRowFunctionKeyCode(systemDefinedData1: data1),
      ShortcutChord.mediaKeyCode(systemDefinedData1: data1),
    ].compactMap { $0 }
  }

  private func effectiveFlags(_ eventFlags: UInt64) -> UInt64 {
    effectiveFlags(
      eventFlags,
      sessionFlags: CGEventSource.flagsState(.combinedSessionState).rawValue
    )
  }

  private func effectiveFlags(_ eventFlags: UInt64, sessionFlags: UInt64) -> UInt64 {
    let sessionFallback = ShortcutChord.withFallbackDeviceFlags(
      eventFlags: eventFlags,
      sessionFlags: sessionFlags
    )
    let flags = ShortcutChord.withFallbackDeviceFlags(
      eventFlags: sessionFallback,
      sessionFlags: lastModifierFlags
    )
    return virtualHyperKey.augmenting(flags)
  }

  private func logUnmatchedTransformationCandidate(keyCode: Int64, flags: UInt64) {
    let keyCode = ShortcutChord.canonicalKeyCode(keyCode)
    guard [99, 120, 122].contains(keyCode) else { return }

    logger.warning(
      "Unmatched transformation key: keyCode=\(keyCode, privacy: .public) leftHyper=\(flags & ShortcutChord.leftHyperModifiers == ShortcutChord.leftHyperModifiers, privacy: .public) flags=\(flags, privacy: .public)"
    )
  }

  private func openApplication(path: String) {
    guard FileManager.default.fileExists(atPath: path) else {
      NSSound.beep()
      return
    }

    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(
      at: URL(fileURLWithPath: path),
      configuration: configuration
    )
  }

  private func hideOtherApplications() {
    let ownProcessIdentifier = ProcessInfo.processInfo.processIdentifier
    for application in NSWorkspace.shared.runningApplications
    where application.processIdentifier != ownProcessIdentifier
      && application.activationPolicy == .regular
    {
      application.hide()
    }
  }

  private func openURL(_ urlString: String) {
    guard let url = URL(string: urlString), NSWorkspace.shared.open(url) else {
      NSSound.beep()
      return
    }
  }

  private func postKey(chord: ShortcutChord) {
    Task { @MainActor [weak self] in
      await self?.modifierRelease.wait()
      self?.postKeyNow(chord: chord)
    }
  }

  private func postKeyNow(chord: ShortcutChord) {
    guard
      let keyDown = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(chord.keyCode),
        keyDown: true
      ),
      let keyUp = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(chord.keyCode),
        keyDown: false
      )
    else { return }

    keyDown.flags = CGEventFlags(rawValue: chord.modifiers | chord.deviceFlags)
    keyUp.flags = CGEventFlags(rawValue: chord.modifiers | chord.deviceFlags)
    keyDown.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
    keyUp.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventMarker)
    keyDown.post(tap: .cghidEventTap)
    keyUp.post(tap: .cghidEventTap)
  }

  private func typeText(_ text: String) {
    let units = Array(text.utf16)
    guard !units.isEmpty else { return }

    Task { @MainActor [weak self] in
      guard let self else { return }
      await modifierRelease.wait()

      for chunk in stride(from: 0, to: units.count, by: Self.typedTextChunkSize) {
        let end = min(chunk + Self.typedTextChunkSize, units.count)
        var slice = Array(units[chunk..<end])
        guard
          let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
          let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        else { return }

        for event in [keyDown, keyUp] {
          event.flags = []
          event.keyboardSetUnicodeString(stringLength: slice.count, unicodeString: &slice)
          event.setIntegerValueField(
            .eventSourceUserData,
            value: Self.syntheticEventMarker
          )
          event.post(tap: .cghidEventTap)
        }
        try? await Task.sleep(for: .milliseconds(2))
      }
    }
  }

  private static let typedTextChunkSize = 16

  private func runAppleScript(_ script: String) {
    var errorInfo: NSDictionary?
    guard NSAppleScript(source: script)?.executeAndReturnError(&errorInfo) != nil else {
      NSSound.beep()
      return
    }
  }

  private func launch(executable: String, arguments: [String]) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    do {
      try process.run()
    } catch {
      NSSound.beep()
    }
  }

  private static let showNotificationCenterScript = """
    tell application "System Events"
      tell process "ControlCenter"
        click (first menu bar item of menu bar 1 whose description is "Clock")
      end tell
    end tell
    """

  private static let closeNotificationsScript = """
    tell application "System Events"
      tell process "NotificationCenter"
        repeat with notificationWindow in windows
          try
            perform action "AXClose" of notificationWindow
          end try
        end repeat
      end tell
      key code 53
    end tell
    """

  static let syntheticEventMarker: Int64 = 0x494E_5055_544D_4154
}
