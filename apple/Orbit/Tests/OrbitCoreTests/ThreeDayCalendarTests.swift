import Foundation
import Testing
import OrbitCore

@Suite("Three-day calendar")
struct ThreeDayCalendarTests {
    @Test func civilWindowBoundaries() {
        #expect(TaskTimelineWindow.days(starting: "2026-12-31") == ["2026-12-31", "2027-01-01", "2027-01-02"])
        #expect(TaskTimelineWindow.days(starting: "2199-12-31") == ["2199-12-29", "2199-12-30", "2199-12-31"])
        #expect(TaskTimelineWindow.shift("1900-01-01", by: -1) == nil)
        #expect(TaskTimelineWindow.shift("2199-12-31", by: 1) == nil)
        #expect(TaskTimelineWindow.shift("2026-01-01", by: Int.min) == nil)
        #expect(TaskTimelineWindow.days(starting: "bad").isEmpty)
    }
    @Test @MainActor func overlappingAndTouchingIntervalsKeepLanes() {
        let tasks = [
            OrbitTask(title: "A", plannedDate: "2026-10-18", plannedTime: "09:00", durationMinutes: 60),
            OrbitTask(title: "B", plannedDate: "2026-10-18", plannedTime: "09:30", durationMinutes: 90),
            OrbitTask(title: "C", plannedDate: "2026-10-18", plannedTime: "10:00", durationMinutes: 30),
            OrbitTask(title: "D", plannedDate: "2026-10-18", plannedTime: "11:00", durationMinutes: 30)]
        let result = TaskTimelineWindow.placements(TaskDayProjector.project(day: "2026-10-18", in: tasks).timedSegments)
        #expect(result.map(\.count) == [2,2,2,1])
        #expect(result.map(\.lane) == [0,1,0,0])
        #expect(Set(result.map { $0.segment.taskID }) == Set(tasks.map(\.id)))
    }
    @Test @MainActor func atomicScheduleMovePreservesMetadataAndReopens() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let store = try OrbitTaskStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let project = try store.addProject(name: "Folder")
        let a = try store.addTask(title: "A", now: now, plannedDate: "2026-10-18", plannedTime: "23:08", durationMinutes: 67,
            projectID: project.id, deadlineDate: "2026-10-22", reminderAt: now.addingTimeInterval(3600))
        let b = try store.addTask(title: "B")
        try store.setPlannedSchedule(date: "2026-10-19", time: "22:35", duration: 67, for: a.id)
        #expect(a.projectID == project.id && a.deadlineDate == "2026-10-22")
        #expect(a.reminderAt == now.addingTimeInterval(3600) && a.createdAt == now)
        #expect(a.title == "A" && !a.isCompleted && b.plannedDate == nil)
        let reopened = try OrbitTaskStore(storeURL: url)
        let saved = try #require(reopened.tasks().first { $0.id == a.id })
        #expect(saved.plannedDate == "2026-10-19" && saved.plannedTime == "22:35" && saved.durationMinutes == 67)
        #expect(TaskDayProjector.project(day: "2026-10-20", in: [saved]).timedSegments.isEmpty)
    }
    @Test @MainActor func invalidScheduleRefusesBeforeMutationAndRetries() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("Orbit.store"))
        let a = try store.addTask(title: "A", plannedDate: "2026-10-18", plannedTime: "09:08", durationMinutes: 7)
        #expect(throws: TaskPlannedDateError.self) { try store.setPlannedSchedule(date: "bad", time: "12:00", duration: 30, for: a.id) }
        #expect(throws: TaskTimeIntervalError.self) { try store.setPlannedSchedule(date: "2026-10-19", time: "24:00", duration: 30, for: a.id) }
        #expect(throws: TaskTimeIntervalError.self) { try store.setPlannedSchedule(date: "2026-10-19", time: "12:00", duration: 4, for: a.id) }
        #expect(throws: TaskTimeIntervalError.self) { try store.setPlannedSchedule(date: "2199-12-31", time: "23:55", duration: 30, for: a.id) }
        #expect(throws: OrbitStoreError.self) { try store.setPlannedSchedule(date: "2026-10-19", time: "12:00", duration: 30, for: UUID()) }
        #expect(a.plannedDate == "2026-10-18" && a.plannedTime == "09:08" && a.durationMinutes == 7)
        try store.setPlannedSchedule(date: "2026-10-19", time: "09:08", duration: 7, for: a.id)
        #expect(a.plannedDate == "2026-10-19" && a.plannedTime == "09:08" && a.durationMinutes == 7)
    }
}
