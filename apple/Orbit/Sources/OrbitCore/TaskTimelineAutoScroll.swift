import Foundation

/// One 30 Hz edge-scroll tick, in points. Velocity ramps up near the edge.
public enum TaskTimelineAutoScroll {
    public static func offset(current: Double, pointer: Double, viewport: Double,
                              minimum: Double, maximum: Double) -> Double {
        guard [current, pointer, viewport, minimum, maximum].allSatisfy(\.isFinite),
              viewport > 0, maximum >= minimum else { return current }
        let band = min(56, viewport / 4)
        let velocity: Double
        if pointer < band { velocity = -min(1, (band - pointer) / band) * 4 }
        else if pointer > viewport - band { velocity = min(1, (pointer - viewport + band) / band) * 4 }
        else { velocity = 0 }
        return min(maximum, max(minimum, current + velocity))
    }
}
