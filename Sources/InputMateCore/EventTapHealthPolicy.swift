public enum EventTapHealthPolicy {
  public static let probeIntervalNanoseconds: UInt64 = 5_000_000_000
  public static let probeTimeoutNanoseconds: UInt64 = 2_000_000_000

  /// A timed-out probe recreates the taps, but only this many times in a row.
  /// Beyond that the taps are left alone until a probe is acknowledged again,
  /// so a session that cannot acknowledge does not turn into a tear-down loop.
  public static let maximumConsecutiveRecoveries = 3

  public static func shouldSendProbe(
    now: UInt64,
    lastProbeSentAt: UInt64?,
    pendingProbeSentAt: UInt64?
  ) -> Bool {
    guard pendingProbeSentAt == nil else { return false }
    guard let lastProbeSentAt else { return true }
    let elapsed = now >= lastProbeSentAt ? now - lastProbeSentAt : 0
    return elapsed >= probeIntervalNanoseconds
  }

  public static func probeTimedOut(now: UInt64, pendingProbeSentAt: UInt64?) -> Bool {
    guard let pendingProbeSentAt else { return false }
    let elapsed = now >= pendingProbeSentAt ? now - pendingProbeSentAt : 0
    return elapsed >= probeTimeoutNanoseconds
  }

  public static func shouldRecoverTaps(consecutiveRecoveries: Int) -> Bool {
    consecutiveRecoveries < maximumConsecutiveRecoveries
  }
}
