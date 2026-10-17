import Foundation
import Testing
import OrbitCore

@Suite("Task batch transactions")
struct TaskBatchTests {
    @Test("complete selection preserves metadata, completed timestamps and unselected tasks")
    @MainActor
    func completionPreservesFields() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("Orbit.store"))
        let at = Date(timeIntervalSince1970: 1_760_000_000)
        let project = try store.addProject(name: "Work")
        let a = try store.addTask(title: "Timed", now: at, plannedDate: "2026-10-18", plannedTime: "09:08",
                                  durationMinutes: 7, projectID: project.id, deadlineDate: "2026-10-20", reminderAt: at.addingTimeInterval(600))
        let b = try store.addTask(title: "Already done")
        let c = try store.addTask(title: "Unselected")
        try store.setCompleted(true, for: b.id, at: at)
        let doneAt = at.addingTimeInterval(50)
        try store.setCompleted(true, for: [a.id, b.id, a.id], at: doneAt)
        #expect(a.completedAt == doneAt)
        #expect(b.completedAt == at)
        #expect(!c.isCompleted)
        #expect(a.title == "Timed" && a.createdAt == at)
        #expect(a.plannedDate == "2026-10-18" && a.plannedTime == "09:08" && a.durationMinutes == 7)
        #expect(a.projectID == project.id && a.deadlineDate == "2026-10-20" && a.reminderAt == at.addingTimeInterval(600))
        try store.setCompleted(true, for: [a.id, b.id], at: doneAt.addingTimeInterval(50))
        try store.setCompleted(true, for: [])
        #expect(a.completedAt == doneAt && b.completedAt == at)
        try store.setCompleted(false, for: [a.id, a.id])
        #expect(!a.isCompleted && b.isCompleted && !c.isCompleted)
    }

    @Test("unknown completion ID rejects entire selection before mutation, then retry works")
    @MainActor
    func completionRejectsUnknown() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("Orbit.store"))
        let a = try store.addTask(title: "First")
        let b = try store.addTask(title: "Second")
        let missing = UUID()
        #expect(throws: OrbitStoreError.taskNotFound(id: missing)) {
            try store.setCompleted(true, for: [a.id, missing, b.id])
        }
        #expect(try store.tasks().allSatisfy { !$0.isCompleted })
        try store.setCompleted(true, for: [a.id, b.id])
        #expect(try store.tasks().allSatisfy(\.isCompleted))
    }

    @Test("unknown delete ID keeps all rows, duplicate delete IDs are safe and retry persists")
    @MainActor
    func deletionRejectsUnknown() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        var store: OrbitTaskStore? = try OrbitTaskStore(storeURL: url)
        let a = try store!.addTask(title: "First")
        let b = try store!.addTask(title: "Second")
        let c = try store!.addTask(title: "Survivor", plannedDate: "2026-10-18")
        let missing = UUID()
        #expect(throws: OrbitStoreError.taskNotFound(id: missing)) {
            try store!.deleteTasks(for: [a.id, missing, b.id])
        }
        #expect(try store!.tasks().count == 3)
        try store!.deleteTasks(for: [])
        try store!.deleteTasks(for: [a.id, b.id, a.id])
        #expect(try store!.tasks().map(\.id) == [c.id])
        store = nil
        let reopened = try OrbitTaskStore(storeURL: url)
        let survivors = try reopened.tasks()
        #expect(survivors.count == 1)
        #expect(survivors.first?.id == c.id && survivors.first?.title == "Survivor")
        #expect(survivors.first?.plannedDate == "2026-10-18" && survivors.first?.isCompleted == false)
    }

    @Test("batch completion survives disk reopen with original UUIDs")
    @MainActor
    func completionReopens() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        var store: OrbitTaskStore? = try OrbitTaskStore(storeURL: url)
        let a = try store!.addTask(title: "A")
        let b = try store!.addTask(title: "B")
        let ids = Set([a.id, b.id])
        let at = Date(timeIntervalSince1970: 1_760_000_000)
        try store!.setCompleted(true, for: Array(ids), at: at)
        store = nil
        let reopened = try OrbitTaskStore(storeURL: url)
        let rows = try reopened.tasks()
        #expect(Set(rows.map(\.id)) == ids)
        #expect(rows.allSatisfy { $0.completedAt == at })
    }
}
