import Foundation

public enum TaskTimelineWindow {
    /// Civil arithmetic in UTC avoids DST changing the number of calendar days.
    public static func shift(_ day: String, by offset: Int) -> String? {
        guard offset >= -200_000, offset <= 200_000 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar),
              let next = calendar.date(byAdding: .day, value: offset, to: date) else { return nil }
        let value = TaskPlannedDate.civilDateString(from: next, calendar: calendar)
        return TaskPlannedDate.validated(value)
    }
    public static func days(starting day: String) -> [String] {
        guard TaskPlannedDate.isValid(day) else { return [] }
        let first = min(day, "2199-12-29")
        return (0..<3).compactMap { shift(first, by: $0) }
    }
    public struct Placement {
        public let segment: TaskDayIntervalSegment
        public let lane: Int
        public let count: Int
    }
    public static func placements(_ segments: [TaskDayIntervalSegment]) -> [Placement] {
        let sorted = segments.sorted {
            if $0.startMinute != $1.startMinute { return $0.startMinute < $1.startMinute }
            if $0.endMinute != $1.endMinute { return $0.endMinute < $1.endMinute }
            return $0.taskID.uuidString < $1.taskID.uuidString
        }
        var output: [Placement] = []
        var cluster: [(TaskDayIntervalSegment, Int)] = []
        var ends: [Int] = []
        var clusterEnd = -1
        func flush() {
            output += cluster.map { Placement(segment: $0.0, lane: $0.1, count: ends.count) }
            cluster = []; ends = []; clusterEnd = -1
        }
        for segment in sorted {
            if segment.startMinute >= clusterEnd { flush() }
            let lane = ends.firstIndex(where: { $0 <= segment.startMinute }) ?? ends.count
            if lane == ends.count { ends.append(segment.endMinute) } else { ends[lane] = segment.endMinute }
            cluster.append((segment, lane))
            clusterEnd = max(segment.endMinute, clusterEnd)
        }
        flush()
        return output
    }
}
