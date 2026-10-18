import Foundation

/// Gesture-only draft. Manual editor precision and stored read rules are unchanged.
public enum TaskTimelineCreation {
    public struct Candidate: Equatable {
        public let time: String
        public let duration: Int
        public var startMinute: Int {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            return parts[0] * 60 + parts[1]
        }
    }

    /// Frozen touch origin on the civil day's scale; drag resizes the initial
    /// 30-minute draft in ten-minute steps. Never extends beyond this day.
    public static func candidate(date: String, startMinute: Double, deltaMinutes: Double) -> Candidate? {
        guard TaskPlannedDate.isValid(date), startMinute.isFinite, deltaMinutes.isFinite,
              abs(startMinute) <= 10_000, abs(deltaMinutes) <= 10_000 else { return nil }
        let start = min(1435, max(0, Int((startMinute / 5).rounded()) * 5))
        let maximum = max(5, ((1440 - start) / 10) * 10)
        let duration = min(maximum, max(5, Int(((30 + deltaMinutes) / 10).rounded()) * 10))
        let time = String(format: "%02d:%02d", start / 60, start % 60)
        guard TaskTimeInterval.end(plannedDate: date, plannedTime: time, durationMinutes: duration) != nil else { return nil }
        return Candidate(time: time, duration: duration)
    }
}
