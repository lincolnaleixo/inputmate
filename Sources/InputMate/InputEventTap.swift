import AppKit
import CoreGraphics
import InputMateCore
import OSLog

final class InputEventTap: @unchecked Sendable {
  private let lifecycleLock = NSLock()
  private var activeEventTap: CFMachPort?
  private var activeRunLoopSource: CFRunLoopSource?
  private var scrollEventTap: CFMachPort?
  private var scrollRunLoopSource: CFRunLoopSource?
  private var gestureEventTap: CFMachPort?
  private var gestureRunLoopSource: CFRunLoopSource?
  private var eventTapRunLoop: CFRunLoop?
  private var eventTapThread: Thread?
  private var eventTapThreadStopped: DispatchSemaphore?
  private var startupSucceeded = false

  private let configurationLock = NSLock()
  private var configuredReversesMouseWheel = false
  private var configuredHandlesKeyboardShortcuts = false

  private let healthLock = NSLock()
  private var pendingProbeSentAt: UInt64?
  private var lastProbeSentAt: UInt64?
  private var hasAcknowledgedProbe = false
  private var probeAcknowledgedAt: TimeInterval?
  private var consecutiveRecoveries = 0

  private var classifier = ScrollInputClassifier()
  private let keyboardShortcuts = KeyboardShortcutController()
  private let logger = Logger(
    subsystem: "com.robot.InputMate",
    category: "InputEventTap"
  )
  private static let probeEventMarker: Int64 = 0x494E_5055_5052_4F42

  var reversesMouseWheel: Bool {
    get { configurationLock.withLock { configuredReversesMouseWheel } }
    set { configurationLock.withLock { configuredReversesMouseWheel = newValue } }
  }

  var handlesKeyboardShortcuts: Bool {
    get { configurationLock.withLock { configuredHandlesKeyboardShortcuts } }
    set { configurationLock.withLock { configuredHandlesKeyboardShortcuts = newValue } }
  }

  var isRunning: Bool {
    lifecycleLock.withLock {
      isUsable(activeEventTap) && isUsable(scrollEventTap) && isUsable(gestureEventTap)
    }
  }

  var isResponsive: Bool {
    isRunning && healthLock.withLock { hasAcknowledgedProbe }
  }

  var diagnosticState: String {
    let taps = lifecycleLock.withLock {
      "active=\(isUsable(activeEventTap)) scroll=\(isUsable(scrollEventTap))"
        + " gesture=\(isUsable(gestureEventTap))"
    }
    let health = healthLock.withLock {
      "acked=\(hasAcknowledgedProbe) pending=\(pendingProbeSentAt != nil)"
        + " recoveries=\(consecutiveRecoveries)"
    }
    let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    let locked = session.flatMap { Self.sessionFlag($0, "CGSSessionScreenIsLocked") }
    let onConsole = session.flatMap { Self.sessionFlag($0, kCGSessionOnConsoleKey as String) }
    return "\(taps) \(health) session=\(Self.sessionIsActive())"
      + " locked=\(locked.map(String.init) ?? "unknown")"
      + " onConsole=\(onConsole.map(String.init) ?? "unknown")"
  }

  var lastDeliveryAcknowledgedAt: TimeInterval? {
    healthLock.withLock { probeAcknowledgedAt }
  }

  func updateKeyboardShortcuts(_ definitions: [KeyboardShortcutDefinition]) {
    keyboardShortcuts.update(definitions: definitions)
  }

  func maintainHealth() -> Bool {
    if !isRunning, !start() {
      return false
    }

    let now = DispatchTime.now().uptimeNanoseconds
    let recovery = healthLock.withLock { () -> (timedOut: Bool, shouldRecover: Bool) in
      let timedOut = EventTapHealthPolicy.probeTimedOut(
        now: now,
        pendingProbeSentAt: pendingProbeSentAt
      )
      guard timedOut else { return (false, false) }
      let shouldRecover = EventTapHealthPolicy.shouldRecoverTaps(
        consecutiveRecoveries: consecutiveRecoveries
      )
      consecutiveRecoveries += 1
      pendingProbeSentAt = nil
      return (true, shouldRecover)
    }

    if recovery.timedOut {
      guard recovery.shouldRecover, Self.sessionIsActive() else {
        logger.error("Input event tap delivery probe keeps timing out; leaving taps in place")
        return isRunning
      }
      logger.error("Input event tap delivery probe timed out; recreating taps")
      stop()
      guard start() else { return false }
      healthLock.withLock { lastProbeSentAt = DispatchTime.now().uptimeNanoseconds }
      return isRunning
    }

    let shouldSendProbe = healthLock.withLock {
      EventTapHealthPolicy.shouldSendProbe(
        now: now,
        lastProbeSentAt: lastProbeSentAt,
        pendingProbeSentAt: pendingProbeSentAt
      )
    }
    if shouldSendProbe {
      postHealthProbe(at: now)
    }
    return isRunning
  }

  private static func sessionFlag(_ session: [String: Any], _ key: String) -> Bool? {
    (session[key] as? NSNumber)?.boolValue
  }

  private static func sessionIsActive() -> Bool {
    guard
      let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    else { return false }

    if sessionFlag(session, "CGSSessionScreenIsLocked") == true {
      return false
    }
    return sessionFlag(session, kCGSessionOnConsoleKey as String) ?? false
  }

  func start() -> Bool {
    guard !isRunning else { return true }
    stop()

    let ready = DispatchSemaphore(value: 0)
    let stopped = DispatchSemaphore(value: 0)
    let thread = Thread { [weak self] in
      guard let self else {
        ready.signal()
        stopped.signal()
        return
      }
      self.runEventTapLoop(ready: ready)
      self.eventTapThreadDidStop()
      stopped.signal()
    }
    thread.name = "InputMate event tap"
    thread.qualityOfService = .userInteractive

    lifecycleLock.withLock {
      startupSucceeded = false
      eventTapThread = thread
      eventTapThreadStopped = stopped
    }
    thread.start()

    guard ready.wait(timeout: .now() + 3) == .success else {
      logger.error("Input event tap thread did not start in time")
      stop()
      return false
    }

    let started = lifecycleLock.withLock { startupSucceeded }
    if started {
      healthLock.withLock {
        pendingProbeSentAt = nil
        lastProbeSentAt = nil
        hasAcknowledgedProbe = false
        probeAcknowledgedAt = nil
      }
      logger.info("Input event taps started on dedicated run loop")
    } else {
      logger.error("Input event taps did not remain enabled after startup")
      stop()
    }
    return started
  }

  private func runEventTapLoop(ready: DispatchSemaphore) {
    let scrollMask = CGEventMask(1) << CGEventType.scrollWheel.rawValue
    let keyDownMask = CGEventMask(1) << CGEventType.keyDown.rawValue
    let keyUpMask = CGEventMask(1) << CGEventType.keyUp.rawValue
    let flagsChangedMask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
    let systemDefinedMask = CGEventMask(1) << NSEvent.EventType.systemDefined.rawValue
    let activeMask =
      scrollMask | keyDownMask | keyUpMask | flagsChangedMask | systemDefinedMask
    let gestureMask = CGEventMask(NSEvent.EventTypeMask.gesture.rawValue)

    guard
      let gestureTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .tailAppendEventTap,
        options: .listenOnly,
        eventsOfInterest: gestureMask,
        callback: gestureEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      ),
      let scrollTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: scrollMask,
        callback: scrollEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      ),
      let activeTap = CGEvent.tapCreate(
        tap: .cghidEventTap,
        place: .headInsertEventTap,
        options: .defaultTap,
        eventsOfInterest: activeMask,
        callback: inputEventTapCallback,
        userInfo: Unmanaged.passUnretained(self).toOpaque()
      )
    else {
      logger.error("Could not create input event taps")
      ready.signal()
      return
    }

    guard
      let gestureSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, gestureTap, 0),
      let scrollSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, scrollTap, 0),
      let activeSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, activeTap, 0)
    else {
      logger.error("Could not create input event tap run-loop sources")
      CFMachPortInvalidate(gestureTap)
      CFMachPortInvalidate(scrollTap)
      CFMachPortInvalidate(activeTap)
      ready.signal()
      return
    }

    let runLoop = CFRunLoopGetCurrent()
    lifecycleLock.withLock {
      eventTapRunLoop = runLoop
      gestureEventTap = gestureTap
      gestureRunLoopSource = gestureSource
      scrollEventTap = scrollTap
      scrollRunLoopSource = scrollSource
      activeEventTap = activeTap
      activeRunLoopSource = activeSource
    }

    CFRunLoopAddSource(runLoop, gestureSource, .commonModes)
    CFRunLoopAddSource(runLoop, scrollSource, .commonModes)
    CFRunLoopAddSource(runLoop, activeSource, .commonModes)
    CGEvent.tapEnable(tap: gestureTap, enable: true)
    CGEvent.tapEnable(tap: scrollTap, enable: true)
    CGEvent.tapEnable(tap: activeTap, enable: true)

    let started = isUsable(activeTap) && isUsable(scrollTap) && isUsable(gestureTap)
    lifecycleLock.withLock {
      startupSucceeded = started
    }
    ready.signal()

    if started {
      CFRunLoopRun()
    }

    keyboardShortcuts.resetTransientState()
    CFRunLoopRemoveSource(runLoop, activeSource, .commonModes)
    CFRunLoopRemoveSource(runLoop, scrollSource, .commonModes)
    CFRunLoopRemoveSource(runLoop, gestureSource, .commonModes)
    invalidate(activeTap)
    invalidate(scrollTap)
    invalidate(gestureTap)

    lifecycleLock.withLock {
      if eventTapRunLoop === runLoop {
        activeRunLoopSource = nil
        activeEventTap = nil
        scrollRunLoopSource = nil
        scrollEventTap = nil
        gestureRunLoopSource = nil
        gestureEventTap = nil
        eventTapRunLoop = nil
        eventTapThread = nil
        eventTapThreadStopped = nil
        startupSucceeded = false
      }
    }
  }

  func stop() {
    let (runLoop, stopped) = lifecycleLock.withLock {
      (eventTapRunLoop, eventTapThreadStopped)
    }
    if let runLoop {
      CFRunLoopStop(runLoop)
      CFRunLoopWakeUp(runLoop)
    }
    if let stopped {
      _ = stopped.wait(timeout: .now() + 3)
    }
    healthLock.withLock {
      pendingProbeSentAt = nil
      lastProbeSentAt = nil
      hasAcknowledgedProbe = false
      probeAcknowledgedAt = nil
    }
  }

  fileprivate func handleGesture(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      logger.warning("Gesture event tap was disabled; attempting immediate recovery")
      let tap = lifecycleLock.withLock { gestureEventTap }
      enable(tap: tap)
      return Unmanaged.passUnretained(event)
    }

    if let nsEvent = NSEvent(cgEvent: event) {
      let touching = nsEvent.touches(matching: .touching, in: nil).count
      classifier.recordGesture(
        touching: touching,
        timestamp: DispatchTime.now().uptimeNanoseconds
      )
      logger.debug("scroll-trace gesture touching=\(touching, privacy: .public)")
    }

    return Unmanaged.passUnretained(event)
  }

  fileprivate func handleInput(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      logger.warning("Input event tap was disabled; attempting immediate recovery")
      let tap = lifecycleLock.withLock { activeEventTap }
      enable(tap: tap)
      return Unmanaged.passUnretained(event)
    }

    let marker = event.getIntegerValueField(.eventSourceUserData)
    if marker == Self.probeEventMarker {
      let isFirstAcknowledgement = healthLock.withLock {
        let isFirstAcknowledgement = !hasAcknowledgedProbe
        hasAcknowledgedProbe = true
        pendingProbeSentAt = nil
        probeAcknowledgedAt = Date().timeIntervalSince1970
        consecutiveRecoveries = 0
        return isFirstAcknowledgement
      }
      if isFirstAcknowledgement {
        logger.info("Input event tap delivery probe acknowledged")
      }
      return nil
    }

    if (type == .keyDown || type == .keyUp) && handlesKeyboardShortcuts
      && keyboardShortcuts.handle(event: event, type: type)
    {
      return nil
    }

    if type == .flagsChanged && handlesKeyboardShortcuts {
      keyboardShortcuts.handleModifierFlagsChanged(flags: event.flags.rawValue)
    }

    if type.rawValue == NSEvent.EventType.systemDefined.rawValue && handlesKeyboardShortcuts
      && keyboardShortcuts.handleSystemDefined(event: event)
    {
      return nil
    }

    return Unmanaged.passUnretained(event)
  }

  fileprivate func handleScroll(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      logger.warning("Scroll event tap was disabled; attempting immediate recovery")
      let tap = lifecycleLock.withLock { scrollEventTap }
      enable(tap: tap)
      return Unmanaged.passUnretained(event)
    }

    guard type == .scrollWheel, reversesMouseWheel else {
      return Unmanaged.passUnretained(event)
    }

    let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
    let scrollPhase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
    let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
    let source = classifier.classify(
      isContinuous: isContinuous,
      scrollPhase: scrollPhase,
      momentumPhase: momentumPhase,
      timestamp: DispatchTime.now().uptimeNanoseconds
    )
    logger.debug(
      """
      scroll-trace continuous=\(isContinuous, privacy: .public) \
      phase=\(scrollPhase, privacy: .public) \
      momentum=\(momentumPhase, privacy: .public) \
      source=\(String(describing: source), privacy: .public)
      """
    )

    if source == .mouse {
      ScrollEventPolicy.reverseDeltas(in: event)
    }
    return Unmanaged.passUnretained(event)
  }

  private func enable(tap: CFMachPort?) {
    guard let tap, CFMachPortIsValid(tap) else { return }
    CGEvent.tapEnable(tap: tap, enable: true)
  }

  private func isUsable(_ tap: CFMachPort?) -> Bool {
    guard let tap, CFMachPortIsValid(tap) else { return false }
    return CGEvent.tapIsEnabled(tap: tap)
  }

  private func postHealthProbe(at timestamp: UInt64) {
    guard
      let event = CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 1,
        wheel1: 0,
        wheel2: 0,
        wheel3: 0
      )
    else {
      logger.error("Could not create input event tap delivery probe")
      return
    }

    event.setIntegerValueField(.eventSourceUserData, value: Self.probeEventMarker)
    healthLock.withLock {
      pendingProbeSentAt = timestamp
      lastProbeSentAt = timestamp
    }
    event.post(tap: .cghidEventTap)
  }

  private func eventTapThreadDidStop() {
    lifecycleLock.withLock {
      guard eventTapThread === Thread.current else { return }
      activeRunLoopSource = nil
      activeEventTap = nil
      scrollRunLoopSource = nil
      scrollEventTap = nil
      gestureRunLoopSource = nil
      gestureEventTap = nil
      eventTapRunLoop = nil
      eventTapThread = nil
      eventTapThreadStopped = nil
      startupSucceeded = false
    }
  }

  private func invalidate(_ tap: CFMachPort) {
    if CFMachPortIsValid(tap) {
      CGEvent.tapEnable(tap: tap, enable: false)
    }
    CFMachPortInvalidate(tap)
  }

  deinit {
    stop()
  }
}

private let gestureEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }
  let tap = Unmanaged<InputEventTap>.fromOpaque(userInfo).takeUnretainedValue()
  return tap.handleGesture(type: type, event: event)
}

private let inputEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }
  let tap = Unmanaged<InputEventTap>.fromOpaque(userInfo).takeUnretainedValue()
  return tap.handleInput(type: type, event: event)
}

private let scrollEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }
  let tap = Unmanaged<InputEventTap>.fromOpaque(userInfo).takeUnretainedValue()
  return tap.handleScroll(type: type, event: event)
}
