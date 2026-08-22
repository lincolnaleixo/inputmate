import CoreGraphics

public enum ScrollEventPolicy {
  public static func inverted(_ value: Int64) -> Int64 {
    value == .min ? .max : -value
  }

  public static func reverseDeltas(in event: CGEvent) {
    reverseAxis(
      in: event,
      deltaField: .scrollWheelEventDeltaAxis1,
      fixedPointField: .scrollWheelEventFixedPtDeltaAxis1,
      pointField: .scrollWheelEventPointDeltaAxis1
    )
    reverseAxis(
      in: event,
      deltaField: .scrollWheelEventDeltaAxis2,
      fixedPointField: .scrollWheelEventFixedPtDeltaAxis2,
      pointField: .scrollWheelEventPointDeltaAxis2
    )
    reverseAxis(
      in: event,
      deltaField: .scrollWheelEventDeltaAxis3,
      fixedPointField: .scrollWheelEventFixedPtDeltaAxis3,
      pointField: .scrollWheelEventPointDeltaAxis3
    )
  }

  private static func reverseAxis(
    in event: CGEvent,
    deltaField: CGEventField,
    fixedPointField: CGEventField,
    pointField: CGEventField
  ) {
    let delta = event.getIntegerValueField(deltaField)
    let fixedPointDelta = event.getDoubleValueField(fixedPointField)
    let pointDelta = event.getIntegerValueField(pointField)

    event.setIntegerValueField(deltaField, value: inverted(delta))
    event.setDoubleValueField(fixedPointField, value: -fixedPointDelta)
    event.setIntegerValueField(pointField, value: inverted(pointDelta))
  }
}
