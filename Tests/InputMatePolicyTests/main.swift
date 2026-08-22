import CoreGraphics
import Foundation
import InputMateCore

@main
struct InputMateTests {
  static func main() {
    testScrollClassification()
    testScrollSequenceLatch()
    testDeltaReversal()
    testEventTapHealthPolicy()
    testShortcutChordMatching()
    testShortcutCaptureAndFallback()
    testMediaKeyNormalization()
    testVirtualHyperKeyState()
    testPressedShortcutKeys()
    testShortcutPreferencePolicy()
    testSpanishPunctuationPolicy()
    testShortcutScopePolicy()
    testMissingScopeDecodesAsGlobal()
    print("All InputMate tests passed.")
  }

  private static func testScrollClassification() {
    var classifier = ScrollInputClassifier()
    expect(
      classifier.classify(
        isContinuous: false,
        scrollPhase: 0,
        momentumPhase: 0,
        timestamp: 1
      ) == .mouse,
      "Discrete scrolling should be classified as mouse input"
    )

    expect(
      classifier.classify(
        isContinuous: true,
        scrollPhase: ScrollPhase.began,
        momentumPhase: 0,
        timestamp: 2
      ) == .trackpad,
      "A phased continuous event should be classified as trackpad input"
    )

    var touchClassifier = ScrollInputClassifier()
    touchClassifier.recordGesture(touching: 2, timestamp: 1_000_000_000)
    expect(
      touchClassifier.classify(
        isContinuous: true,
        scrollPhase: 0,
        momentumPhase: 0,
        timestamp: 1_100_000_000
      ) == .trackpad,
      "Recent two-finger evidence should identify a trackpad"
    )

    expect(
      touchClassifier.classify(
        isContinuous: true,
        scrollPhase: 0,
        momentumPhase: 0,
        timestamp: 2_000_000_000
      ) == .mouse,
      "Stale touch evidence should not classify a mouse as a trackpad"
    )
  }

  private static func testScrollSequenceLatch() {
    var classifier = ScrollInputClassifier()
    _ = classifier.classify(
      isContinuous: true,
      scrollPhase: ScrollPhase.began,
      momentumPhase: 0,
      timestamp: 1
    )

    expect(
      classifier.classify(
        isContinuous: true,
        scrollPhase: 0,
        momentumPhase: 0,
        timestamp: 5_000_000_000
      ) == .trackpad,
      "A trackpad sequence should remain latched during a pause"
    )

    _ = classifier.classify(
      isContinuous: true,
      scrollPhase: ScrollPhase.ended,
      momentumPhase: 0,
      timestamp: 5_000_000_001
    )

    expect(
      classifier.classify(
        isContinuous: true,
        scrollPhase: 0,
        momentumPhase: 0,
        timestamp: 6_000_000_000
      ) == .mouse,
      "A phaseless event after a completed gesture should classify as mouse input"
    )
  }

  private static func testDeltaReversal() {
    expect(ScrollEventPolicy.inverted(42) == -42, "Positive deltas should invert")
    expect(ScrollEventPolicy.inverted(-42) == 42, "Negative deltas should invert")
    expect(ScrollEventPolicy.inverted(.min) == .max, "Minimum Int64 should not overflow")

    guard
      let event = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .line,
        wheelCount: 2,
        wheel1: 3,
        wheel2: -2,
        wheel3: 0
      )
    else {
      fatalError("Could not create a synthetic scroll event")
    }

    ScrollEventPolicy.reverseDeltas(in: event)
    expect(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3,
      "Vertical scroll delta should reverse"
    )
    expect(
      event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == 2,
      "Horizontal scroll delta should reverse"
    )
  }

  private static func testEventTapHealthPolicy() {
    expect(
      EventTapHealthPolicy.shouldSendProbe(
        now: 1,
        lastProbeSentAt: nil,
        pendingProbeSentAt: nil
      ),
      "A new event tap should send an initial probe"
    )

    expect(
      !EventTapHealthPolicy.shouldSendProbe(
        now: EventTapHealthPolicy.probeIntervalNanoseconds * 2,
        lastProbeSentAt: 1,
        pendingProbeSentAt: 2
      ),
      "A pending probe should block another probe"
    )

    expect(
      EventTapHealthPolicy.probeTimedOut(
        now: EventTapHealthPolicy.probeTimeoutNanoseconds + 10,
        pendingProbeSentAt: 1
      ),
      "A stale pending probe should time out"
    )

    expect(
      EventTapHealthPolicy.shouldRecoverTaps(consecutiveRecoveries: 0),
      "The first failure should allow tap recovery"
    )
    expect(
      !EventTapHealthPolicy.shouldRecoverTaps(
        consecutiveRecoveries: EventTapHealthPolicy.maximumConsecutiveRecoveries
      ),
      "Repeated failures should stop tap recreation"
    )
  }

  private static func testShortcutChordMatching() {
    let leftHyperF1 = ShortcutChord(
      keyCode: 122,
      modifiers: ShortcutChord.leftHyperModifiers,
      deviceFlags: ShortcutChord.leftHyperDeviceFlags
    )

    expect(
      leftHyperF1.matches(
        keyCode: 122,
        flags: ShortcutChord.leftHyperModifiers | ShortcutChord.leftHyperDeviceFlags
      ),
      "The exact left Hyper F1 chord should match"
    )

    expect(
      leftHyperF1.matches(
        keyCode: 122,
        flags: ShortcutChord.leftHyperModifiers | ShortcutChord.function
          | ShortcutChord.leftHyperDeviceFlags
      ),
      "Fn should not change a function-key shortcut identity"
    )

    expect(
      !leftHyperF1.matches(
        keyCode: 122,
        flags: ShortcutChord.leftHyperModifiers
          | ShortcutChord.rightShift
          | ShortcutChord.leftControl
          | ShortcutChord.leftOption
          | ShortcutChord.leftCommand
      ),
      "A right-side modifier should not match a left-side chord"
    )

    let f3 = ShortcutChord(
      keyCode: 99,
      modifiers: ShortcutChord.leftHyperModifiers,
      deviceFlags: ShortcutChord.leftHyperDeviceFlags
    )
    expect(
      f3.matches(
        keyCode: 0xA0,
        flags: ShortcutChord.leftHyperModifiers | ShortcutChord.leftHyperDeviceFlags
      ),
      "Mission Control should canonicalize to F3"
    )
  }

  private static func testShortcutCaptureAndFallback() {
    let unrelatedFlag: UInt64 = 0x1_0000_0000
    let captured = ShortcutChord.capturing(
      keyCode: 8,
      flags: ShortcutChord.leftHyperModifiers
        | ShortcutChord.leftHyperDeviceFlags
        | unrelatedFlag
    )

    expect(captured.keyCode == 8, "Capture should preserve the key code")
    expect(
      captured.modifiers == ShortcutChord.leftHyperModifiers,
      "Capture should keep only supported modifier flags"
    )
    expect(
      captured.deviceFlags == ShortcutChord.leftHyperDeviceFlags,
      "Capture should preserve modifier sides"
    )

    let sessionFlags = ShortcutChord.leftHyperModifiers | ShortcutChord.leftHyperDeviceFlags
    expect(
      ShortcutChord.withFallbackDeviceFlags(
        eventFlags: ShortcutChord.leftHyperModifiers,
        sessionFlags: sessionFlags
      ) == sessionFlags,
      "Session state should restore missing side flags"
    )
  }

  private static func testMediaKeyNormalization() {
    let brightnessUpDown = Int64((2 << 16) | (0x0A << 8))
    let brightnessDownUp = Int64((3 << 16) | (0x0B << 8))

    expect(
      ShortcutChord.mediaKeyCode(systemDefinedData1: brightnessUpDown)
        == ShortcutChord.brightnessUpKeyCode,
      "Brightness Up should normalize to the public media key code"
    )
    expect(
      ShortcutChord.topRowFunctionKeyCode(systemDefinedData1: brightnessDownUp) == 122,
      "The physical Brightness Down key should normalize to F1"
    )
    expect(
      ShortcutChord.isSystemDefinedKeyDown(data1: brightnessUpDown),
      "System-defined key down should be detected"
    )
    expect(
      ShortcutChord.isSystemDefinedKeyUp(data1: brightnessDownUp),
      "System-defined key up should be detected"
    )
  }

  private static func testVirtualHyperKeyState() {
    var state = VirtualHyperKeyState()
    expect(!state.isActive, "Virtual Hyper should start released")
    expect(
      state.handle(
        keyCode: VirtualHyperKeyState.keyCode,
        isKeyDown: true,
        isKeyUp: false
      ),
      "Virtual Hyper key down should be consumed"
    )
    expect(state.isActive, "Virtual Hyper key down should activate the state")
    expect(
      state.augmenting(0)
        == ShortcutChord.leftHyperModifiers | ShortcutChord.leftHyperDeviceFlags,
      "Active Virtual Hyper should add exact left-side flags"
    )
    expect(
      state.handle(
        keyCode: VirtualHyperKeyState.keyCode,
        isKeyDown: false,
        isKeyUp: true
      ),
      "Virtual Hyper key up should be consumed"
    )
    expect(!state.isActive, "Virtual Hyper key up should release the state")
  }

  private static func testPressedShortcutKeys() {
    var pressed = PressedShortcutKeys()
    expect(pressed.begin(keyCode: 122), "First key down should begin a press")
    expect(!pressed.begin(keyCode: 122), "Repeated key down should not begin twice")
    expect(
      pressed.end(candidateKeyCodes: [120, 122]) == 122,
      "Key up should end the matching candidate"
    )
    expect(pressed.begin(keyCode: 122), "The key should be reusable after key up")
    pressed.endAll(candidateKeyCodes: [122])
    expect(pressed.begin(keyCode: 122), "Bulk release should clear the key")
  }

  private struct PolicyShortcut: Equatable {
    let id: String
    let chord: ShortcutChord
  }

  private static func testShortcutPreferencePolicy() {
    let retained = PolicyShortcut(
      id: "retained",
      chord: ShortcutChord(
        keyCode: 46,
        modifiers: ShortcutChord.command,
        deviceFlags: ShortcutChord.rightCommand
      )
    )
    let removed = PolicyShortcut(
      id: "legacy",
      chord: ShortcutPreferencePolicy.legacyLeftHyperTChord
    )

    let defaults = ShortcutPreferencePolicy.sanitizedDefaults(
      from: [retained, removed],
      chord: { $0.chord }
    )
    expect(defaults == [retained], "Sanitized defaults should remove the legacy chord")

    let migration = ShortcutPreferencePolicy.migrate(
      [removed, retained],
      fromVersion: 0,
      chord: { $0.chord }
    )
    expect(migration.definitions == [retained], "Migration should remove the legacy chord")
    expect(migration.didMigrate, "Old preference data should report a migration")
    expect(
      migration.version == ShortcutPreferencePolicy.currentMigrationVersion,
      "Migration should record the current version"
    )

    let repeated = ShortcutPreferencePolicy.migrate(
      migration.definitions,
      fromVersion: migration.version,
      chord: { $0.chord }
    )
    expect(!repeated.didMigrate, "A completed migration should be idempotent")
  }

  private static func testSpanishPunctuationPolicy() {
    expect(
      SpanishPunctuationPolicy.closingMarksOnly(in: "Hola, ¿qué tal? ¡Muy bien!")
        == "Hola, qué tal? Muy bien!",
      "Opening Spanish punctuation should be removed"
    )
  }

  private struct ScopedShortcut: Equatable {
    let id: String
    var isEnabled = true
    var matches = true
    var scope: ShortcutAppScope?
  }

  private static let editorBundleID = "com.example.Editor"
  private static let browserBundleID = "com.example.Browser"

  private static func select(
    _ shortcuts: [ScopedShortcut],
    frontmostBundleID: String?
  ) -> ScopedShortcut? {
    ShortcutScopePolicy.select(
      from: shortcuts,
      frontmostBundleID: frontmostBundleID,
      isEnabled: { $0.isEnabled },
      matchesChord: { $0.matches },
      scope: { $0.scope }
    )
  }

  private static func testShortcutScopePolicy() {
    expect(
      ShortcutScopePolicy.appliesTo(scope: nil, frontmostBundleID: editorBundleID),
      "A missing scope should be global"
    )
    expect(
      ShortcutScopePolicy.appliesTo(
        scope: ShortcutAppScope(bundleIdentifiers: ["com.example.editor"]),
        frontmostBundleID: editorBundleID
      ),
      "Scope matching should be case-insensitive"
    )

    let shortcuts = [
      ScopedShortcut(id: "global"),
      ScopedShortcut(
        id: "editor",
        scope: ShortcutAppScope(bundleIdentifiers: [editorBundleID])
      ),
    ]
    expect(
      select(shortcuts, frontmostBundleID: editorBundleID)?.id == "editor",
      "A matching scoped shortcut should beat a global shortcut"
    )
    expect(
      select(shortcuts, frontmostBundleID: browserBundleID)?.id == "global",
      "The global shortcut should win when no scope applies"
    )

    expect(
      !ShortcutScopePolicy.scopesIntersect(
        ShortcutAppScope(bundleIdentifiers: [editorBundleID]),
        ShortcutAppScope(bundleIdentifiers: [browserBundleID])
      ),
      "Disjoint scopes should coexist"
    )
    expect(
      ShortcutScopePolicy.scopesIntersect(
        nil,
        ShortcutAppScope(bundleIdentifiers: [browserBundleID])
      ),
      "A global shortcut should intersect every scoped shortcut"
    )

    let chord = ShortcutChord(keyCode: 8, modifiers: ShortcutChord.command, deviceFlags: 0)
    struct ConflictCandidate {
      let id: String
      let enabled: Bool
      let chord: ShortcutChord
      let scope: ShortcutAppScope?
    }
    let candidates = [
      ConflictCandidate(
        id: "editor",
        enabled: true,
        chord: chord,
        scope: ShortcutAppScope(bundleIdentifiers: [editorBundleID])
      ),
      ConflictCandidate(
        id: "browser",
        enabled: true,
        chord: chord,
        scope: ShortcutAppScope(bundleIdentifiers: [browserBundleID])
      ),
    ]

    expect(
      ShortcutScopePolicy.conflict(
        in: candidates,
        excludingID: "candidate",
        chord: chord,
        scope: ShortcutAppScope(bundleIdentifiers: [editorBundleID]),
        id: { $0.id },
        isEnabled: { $0.enabled },
        chord: { $0.chord },
        scope: { $0.scope }
      )?.id == "editor",
      "An overlapping scope should conflict"
    )

    expect(
      ShortcutScopePolicy.coexisting(
        in: candidates,
        excludingID: "candidate",
        chord: chord,
        scope: ShortcutAppScope(bundleIdentifiers: [editorBundleID]),
        id: { $0.id },
        isEnabled: { $0.enabled },
        chord: { $0.chord },
        scope: { $0.scope }
      ).map(\.id) == ["browser"],
      "A disjoint scope should be reported as coexisting"
    )
  }

  private struct DecodableShortcut: Codable {
    var id: String
    var appScope: ShortcutAppScope? = nil
  }

  private static func testMissingScopeDecodesAsGlobal() {
    let legacyJSON = Data(#"{"id":"example"}"#.utf8)
    guard
      let decoded = try? JSONDecoder().decode(DecodableShortcut.self, from: legacyJSON)
    else {
      fatalError("A shortcut without an appScope key should still decode")
    }
    expect(decoded.appScope == nil, "A missing appScope should decode as global")
  }

  private static func expect(
    _ condition: @autoclosure () -> Bool,
    _ message: String
  ) {
    guard condition() else {
      fatalError(message)
    }
  }
}
