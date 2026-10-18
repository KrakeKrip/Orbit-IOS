import Foundation
import Testing
@testable import OrbitCore

@Test func reminderSeedUsesLocalStartMinusTenMinutes() {
    let zone = TimeZone(secondsFromGMT: 10800)!
    let result = TaskReminder.suggestedDate(plannedDate: "2026-10-18", plannedTime: "14:08",
                                          now: Date(timeIntervalSince1970: 0), timeZone: zone)
    #expect(ISO8601DateFormatter().string(from: result) == "2026-10-18T10:58:00Z")
    let midnight = TaskReminder.suggestedDate(plannedDate: "2026-10-18", plannedTime: "00:05", timeZone: zone)
    #expect(ISO8601DateFormatter().string(from: midnight) == "2026-10-17T20:55:00Z")
}

@Test func reminderSeedWithoutStartFallsBackAndDoesNotNormalizeDSTGap() {
    let now = Date(timeIntervalSince1970: 100)
    let expected = Date(timeIntervalSince1970: 3720)
    #expect(TaskReminder.suggestedDate(plannedDate: nil, plannedTime: nil, now: now) == expected)
    #expect(TaskReminder.suggestedDate(plannedDate: "2026-10-18", plannedTime: "24:00", now: now) == expected)
    #expect(TaskReminder.suggestedDate(plannedDate: "2026-03-08", plannedTime: "02:30", now: now,
                                     timeZone: TimeZone(identifier: "America/New_York")!) == expected)
}
