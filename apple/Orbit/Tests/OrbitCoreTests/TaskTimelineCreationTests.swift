import Foundation
import Testing
import OrbitCore

@Suite("Calendar gesture creation draft")
struct TaskTimelineCreationTests {
    @Test func snappingAndMinimum() {
        let start = TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 548, deltaMinutes: 0)
        #expect(start?.time == "09:10" && start?.duration == 30)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 548, deltaMinutes: 16)?.duration == 50)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 548, deltaMinutes: -100)?.duration == 5)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 1439, deltaMinutes: 100)?.time == "23:55")
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 1439, deltaMinutes: 100)?.duration == 5)
    }
    @Test func boundariesAndInvalidValues() {
        #expect(TaskTimelineCreation.candidate(date: "bad", startMinute: 0, deltaMinutes: 0) == nil)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: .nan, deltaMinutes: 0) == nil)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 0, deltaMinutes: .infinity) == nil)
        #expect(TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: 0, deltaMinutes: .greatestFiniteMagnitude) == nil)
        #expect(TaskTimelineCreation.candidate(date: "2199-12-31", startMinute: 1435, deltaMinutes: 0) == nil)
        #expect(TaskTimelineCreation.candidate(date: "1900-01-01", startMinute: -30, deltaMinutes: 0)?.time == "00:00")
    }
    @Test func everyDraftStaysWritableAndInsideDay() {
        for minute in stride(from: 0, through: 1440, by: 3) {
            for delta in [-100.0, 0, 17, 1500] {
                let value = TaskTimelineCreation.candidate(date: "2026-10-18", startMinute: Double(minute), deltaMinutes: delta)
                #expect(value != nil)
                if let value {
                    #expect(value.startMinute % 5 == 0)
                    #expect(value.duration == 5 || value.duration % 10 == 0)
                    #expect(value.startMinute + value.duration <= 1440)
                    #expect(TaskTimeInterval.isWritableDuration(value.duration))
                }
            }
        }
    }
}
