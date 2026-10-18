import Foundation
import Testing
import OrbitCore

@Suite("Overdue planning and atomic reschedule")
struct TaskRescheduleTests {
    @Test @MainActor func overdueUsesPlanningDayAndCompletion() throws {
        let a = OrbitTask(title: "Past")
        a.setPlannedDate("2026-10-15")
        #expect(TaskDaySelection.isOverdue(a, before: "2026-10-18"))
        #expect(!TaskDaySelection.isOverdue(a, before: "2026-10-15"))
        #expect(!TaskDaySelection.isOverdue(a, before: "invalid"))
        a.complete()
        #expect(!TaskDaySelection.isOverdue(a, before: "2026-10-18"))
        #expect(!TaskDaySelection.isOverdue(OrbitTask(title: "Undated"), before: "2026-10-18"))
    }

    @Test @MainActor func movePreservesFieldsAndPersists() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let store = try OrbitTaskStore(storeURL: url)
        let at = Date(timeIntervalSince1970: 1_760_000_000)
        let project = try store.addProject(name: "Work")
        let a = try store.addTask(title: "Timed", now: at, plannedDate: "2026-10-15", plannedTime: "23:08",
            durationMinutes: 67, projectID: project.id, deadlineDate: "2026-10-20", reminderAt: at.addingTimeInterval(600))
        let b = try store.addTask(title: "Other", plannedDate: "2026-10-16")
        let c = try store.addTask(title: "Untouched", plannedDate: "2026-10-17")
        try store.rescheduleTasks([a.id, b.id, a.id], to: "2026-10-18")
        #expect(a.plannedTime == "23:08" && a.durationMinutes == 67)
        #expect(a.projectID == project.id && a.deadlineDate == "2026-10-20")
        #expect(a.reminderAt == at.addingTimeInterval(600) && a.createdAt == at && !a.isCompleted)
        #expect(c.plannedDate == "2026-10-17")
        let reopened = try OrbitTaskStore(storeURL: url)
        let saved = try reopened.tasks().filter { $0.id == a.id || $0.id == b.id }
        #expect(saved.count == 2 && saved.allSatisfy { $0.plannedDate == "2026-10-18" })
    }

    @Test @MainActor func invalidSelectionRejectsWholeMoveAndRetries() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("Orbit.store"))
        let a = try store.addTask(title: "Untimed", plannedDate: "2026-10-15")
        let b = try store.addTask(title: "Overnight", plannedDate: "2026-10-15", plannedTime: "23:30", durationMinutes: 120)
        #expect(throws: TaskTimeIntervalError.self) { try store.rescheduleTasks([a.id,b.id], to: "2199-12-31") }
        #expect(a.plannedDate == "2026-10-15" && b.plannedDate == "2026-10-15")
        #expect(throws: OrbitStoreError.self) { try store.rescheduleTasks([a.id,UUID()], to: "2026-10-18") }
        #expect(throws: TaskPlannedDateError.self) { try store.rescheduleTasks([a.id,b.id], to: "bad") }
        #expect(a.plannedDate == "2026-10-15" && b.plannedDate == "2026-10-15")
        try store.rescheduleTasks([], to: "2026-10-18")
        try store.rescheduleTasks([a.id,b.id], to: "2026-10-18")
        #expect(a.plannedDate == "2026-10-18" && b.plannedDate == "2026-10-18")
    }
}
