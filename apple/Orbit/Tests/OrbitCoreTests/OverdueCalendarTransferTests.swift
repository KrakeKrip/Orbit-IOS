import Foundation
import Testing
@testable import OrbitCore

struct OverdueCalendarTransferTests {
    @Test @MainActor func dropUsesNewClockPreservesLengthAndMetadataAfterReopen() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let store = try OrbitTaskStore(storeURL: url)
        let task = try store.addTask(title: "Missed", plannedDate: "2026-10-23")
        let reminder = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) + 3600)
        try store.updateTask(id: task.id, title: task.title, plannedDate: "2026-10-23",
            plannedTime: "15:00", durationMinutes: 90, projectID: nil,
            deadlineDate: "2026-10-24", reminderAt: reminder)
        let id = task.id, created = task.createdAt
        #expect(TaskDaySelection.isOverdue(task, before: "2026-10-26"))
        let drop = try #require(TaskTimelineAdjustment.candidate(date: "2026-10-26",
            time: "00:00", duration: 90, deltaMinutes: 23 * 60 + 30, edge: .move))
        try store.setPlannedSchedule(date: "2026-10-26", time: drop.time, duration: drop.duration, for: id)
        let reopened = try OrbitTaskStore(storeURL: url)
        let saved = try #require(reopened.tasks().first)
        #expect(saved.id == id && saved.createdAt == created)
        #expect(saved.plannedDate == "2026-10-26" && saved.plannedTime == "23:30" && saved.durationMinutes == 90)
        #expect(saved.deadlineDate == "2026-10-24" && saved.reminderAt == reminder)
        #expect(!TaskDaySelection.isOverdue(saved, before: "2026-10-26"))
    }
}
