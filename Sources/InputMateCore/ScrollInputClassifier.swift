public enum ScrollInputSource: Equatable, Sendable {
  case mouse
  case trackpad
}

/// Decides whether a scroll event came from a wheel mouse or a trackpad.
public struct ScrollInputClassifier: Sendable {
  private static let touchRecognitionWindow: UInt64 = 222_000_000

  private var lastTouchTimestamp: UInt64?
  private var touchingCount = 0
  private var latchedSource: ScrollInputSource?

  public init() {}

  public mutating func recordGesture(touching count: Int, timestamp: UInt64) {
    guard count >= 2 else { return }
    lastTouchTimestamp = timestamp
    touchingCount = max(touchingCount, count)
  }

  public mutating func classify(
    isContinuous: Bool,
    scrollPhase: Int64,
    momentumPhase: Int64,
    timestamp: UInt64
  ) -> ScrollInputSource {
    defer { touchingCount = 0 }

    if !isContinuous {
      latchedSource = nil
      return .mouse
    }

    if scrollPhase != 0 || momentumPhase != 0 {
      let source = latchedSource ?? .trackpad
      if ScrollPhase.endsSequence(scrollPhase: scrollPhase, momentumPhase: momentumPhase) {
        latchedSource = nil
      } else {
        latchedSource = source
      }
      return source
    }

    if let latchedSource {
      return latchedSource
    }

    let touchIsRecent =
      elapsed(since: lastTouchTimestamp, now: timestamp) < Self.touchRecognitionWindow
    return touchingCount >= 2 && touchIsRecent ? .trackpad : .mouse
  }

  private func elapsed(since timestamp: UInt64?, now: UInt64) -> UInt64 {
    guard let timestamp, now >= timestamp else { return .max }
    return now - timestamp
  }
}

public enum ScrollPhase {
  public static let began: Int64 = 1
  public static let changed: Int64 = 2
  public static let ended: Int64 = 4
  public static let cancelled: Int64 = 8
  public static let mayBegin: Int64 = 128

  public static let momentumEnded: Int64 = 3

  public static func endsSequence(scrollPhase: Int64, momentumPhase: Int64) -> Bool {
    if momentumPhase != 0 {
      return momentumPhase == momentumEnded
    }
    return scrollPhase == ended || scrollPhase == cancelled
  }
}
