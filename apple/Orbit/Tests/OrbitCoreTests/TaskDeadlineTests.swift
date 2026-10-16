import Foundation
import Testing
import OrbitCore

@Suite("Task deadlines")
struct TaskDeadlineTests {
    @Test("Deadline is civil, independent, due through today; completion and invalid days are safe")
    func status() throws {
        for invalid in ["2026-02-29", "2026-1-01", "1899-12-31", "2200-01-01", "2026-10-16T00:00Z", "", "2026-13-01"] {
            #expect(throws: TaskDeadlineError.invalid(invalid)) { try TaskDeadline.validate(invalid) }
            #expect(!TaskDeadline.isOverdue(invalid, completed: false, today: "2026-10-16"))
        }
        for valid in ["1900-01-01", "2000-02-29", "2199-12-31"] { try TaskDeadline.validate(valid) }
        try TaskDeadline.validate(nil)
        #expect(!TaskDeadline.isOverdue(nil, completed: false, today: "2026-10-16"))
        #expect(!TaskDeadline.isOverdue("2026-10-16", completed: false, today: "2026-10-16"))
        #expect(TaskDeadline.isOverdue("2026-10-16", completed: false, today: "2026-10-17"))
        #expect(!TaskDeadline.isOverdue("2026-10-16", completed: true, today: "2026-10-17"))
        #expect(!TaskDeadline.isOverdue("2026-10-18", completed: false, today: "2026-10-17"))
        #expect(!TaskDeadline.isOverdue("2026-10-16", completed: false, today: "not a day"))
    }

    @Test("Deadline-only create, atomic refusal, change/clear and reopen preserve scheduling and project")
    @MainActor func store() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("deadline.store")
        let id: UUID; let otherID: UUID; let projectID: UUID
        let at = Date(timeIntervalSince1970: 100)
        do {
            let s = try OrbitTaskStore(storeURL: url)
            let p = try s.addProject(name: "Проект"); projectID = p.id
            let t = try s.addTask(title: "Срок отдельно", now: at, deadlineDate: "2026-10-01")
            id = t.id
            #expect(t.plannedDate == nil && t.plannedTime == nil && t.projectID == nil)
            let other = try s.addTask(title: "Другая", plannedDate: "2026-10-16", plannedTime: "23:08", durationMinutes: 100, projectID: p.id, deadlineDate: "2026-10-15")
            otherID = other.id
            try s.setCompleted(true, for: other.id, at: at)
            for invalid in ["2026-02-29", "1899-01-01", "2200-01-01"] {
                #expect(throws: TaskDeadlineError.invalid(invalid)) { try s.setDeadlineDate(invalid, for: other.id) }
                #expect(throws: TaskDeadlineError.invalid(invalid)) { try s.addTask(title: "Не вставлять", deadlineDate: invalid) }
                #expect(try s.tasks().count == 2)
                #expect(other.deadlineDate == "2026-10-15")
            }
            let missing = UUID()
            #expect(throws: OrbitStoreError.taskNotFound(id: missing)) { try s.setDeadlineDate(nil, for: missing) }
            try s.setDeadlineDate("2026-10-17", for: other.id)
            try s.setDeadlineDate("2026-10-17", for: other.id)
            #expect(other.id == otherID && other.createdAt != at && other.completedAt == at)
            #expect(other.plannedDate == "2026-10-16" && other.plannedTime == "23:08" && other.durationMinutes == 100 && other.projectID == p.id)
            #expect(t.deadlineDate == "2026-10-01")
            try s.setDeadlineDate(nil, for: t.id)
        }
        let s = try OrbitTaskStore(storeURL: url)
        let rows = try s.tasks()
        let other = try #require(rows.first { $0.id == otherID })
        #expect(other.deadlineDate == "2026-10-17" && other.projectID == projectID && other.completedAt == at)
        #expect(rows.first { $0.id == id }?.deadlineDate == nil)
        // Existing scheduling/project/title operations must not erase or move the deadline.
        try s.setPlannedDate("2026-10-20", for: otherID)
        try s.setPlannedInterval(plannedTime: "10:08", durationMinutes: 7, for: otherID)
        try s.renameTask(title: "Новое название", for: otherID)
        try s.setProject(nil, for: otherID)
        try s.setCompleted(false, for: otherID)
        try s.setPlannedDate(nil, for: otherID)
        #expect(other.deadlineDate == "2026-10-17" && other.plannedTime == nil && other.durationMinutes == nil)
        #expect(OrbitTask(title: "Old init").deadlineDate == nil)
        #expect(try s.addTask(title: "Retry", deadlineDate: "2026-02-28").deadlineDate == "2026-02-28")
    }

    @Test("Actual previous binary task with project upgrades with nil deadline", .enabled(if: ProcessInfo.processInfo.environment["ORBIT_DEADLINE_FIXTURE"] != nil))
    @MainActor func upgrade() throws {
        let path = try #require(ProcessInfo.processInfo.environment["ORBIT_DEADLINE_FIXTURE"])
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("upgrade.store")
        for suffix in ["", "-wal", "-shm"] {
            let src = URL(fileURLWithPath: path + suffix)
            if FileManager.default.fileExists(atPath: src.path) { try FileManager.default.copyItem(at: src, to: URL(fileURLWithPath: url.path + suffix)) }
        }
        let oracle = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: path + ".json"))) as? [String: String])
        let id: UUID
        do {
            let s = try OrbitTaskStore(storeURL: url)
            let t = try #require(s.tasks().first); id = t.id
            #expect(t.id.uuidString == oracle["task"] && t.projectID?.uuidString == oracle["project"])
            #expect(t.title == "Старая задача" && t.deadlineDate == nil)
            #expect(t.createdAt == Date(timeIntervalSince1970: 100) && t.completedAt == Date(timeIntervalSince1970: 200))
            #expect(t.plannedDate == "2026-10-16" && t.plannedTime == "23:08" && t.durationMinutes == 100)
            #expect(try s.projects().first?.name == "Прежний проект")
            try s.setDeadlineDate("2026-10-20", for: id)
        }
        let reopened = try OrbitTaskStore(storeURL: url)
        #expect(try reopened.tasks().first?.deadlineDate == "2026-10-20")
        #expect(try reopened.tasks().first?.id == id)
    }
}
