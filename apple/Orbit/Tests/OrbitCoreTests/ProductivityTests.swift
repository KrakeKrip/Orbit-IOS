import Foundation
import Testing
@testable import OrbitCore

@Suite("Productivity") @MainActor struct ProductivityTests {
    @Test("Upgrade actual v2 schema", .enabled(if: ProcessInfo.processInfo.environment["ORBIT_V2_FIXTURE"] != nil))
    func migrateV2() throws {
        let source = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ORBIT_V2_FIXTURE"]!)
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: source, to: dir)
        defer { try? FileManager.default.removeItem(at: dir) }
        let before = try OrbitBackup.decode(Data(contentsOf: dir.appendingPathComponent("before.json")))
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("store"))
        #expect(try store.backup().tasks == before.tasks)
        #expect(try store.backup().projects == before.projects)
        #expect(try store.backup().tags == before.tags)
        let task = try #require(store.tasks().first)
        try store.updateTask(id: task.id, title: task.title, plannedDate: task.plannedDate,
                             plannedTime: task.plannedTime, durationMinutes: task.durationMinutes,
                             projectID: task.projectID, deadlineDate: task.deadlineDate, reminderAt: task.reminderAt,
                             subtasks: [TaskSubtask(title: "New")], repeatRule: .weekly, updateRepeat: true)
        let reopened = try OrbitTaskStore(storeURL: dir.appendingPathComponent("store"))
        #expect(try reopened.tasks().first?.repeatRule == .weekly)
        #expect(try reopened.tasks().first?.subtasks.count == 1)
    }
    @Test func quickInputIsConservative() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = TaskPlannedDate.date(fromCivilDateString: "2026-10-29", calendar: cal)!
        let value = TaskQuickInput.parse("Завтра в 15:00 созвон на час", now: now, calendar: cal)
        #expect(value?.title == "созвон")
        #expect(value?.day == "2026-10-30" && value?.time == "15:00" && value?.duration == 60)
        #expect(TaskQuickInput.parse("в 28:70 ошибка", now: now) == nil)
        #expect(TaskQuickInput.parse("Прочитать Завтрак у Тиффани", now: now) == nil)
        #expect(TaskQuickInput.parse("завтра", now: now) == nil)
        #expect(TaskQuickInput.parse("в 15:00 звонок на 99999999 часов", now: now) == nil)
    }
    @Test func repeatCalendarBoundaries() {
        #expect(TaskRepeat.weekdays.next(after: "2026-10-30") == "2026-11-02")
        #expect(TaskRepeat.monthly.next(after: "2028-01-31") == "2028-02-29")
        #expect(TaskRepeat.weekly.next(after: "2026-12-31") == "2027-01-07")
        #expect(TaskRepeat.daily.next(after: "2199-12-31") == nil)
    }
    @Test func persistenceRepeatUndoAndBackup() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("store")
        let store = try OrbitTaskStore(storeURL: url)
        let task = try store.addTask(title: "Workout", plannedDate: "2026-10-29", plannedTime: "10:00", durationMinutes: 60,
                                     subtasks: [TaskSubtask(title: "Warm up", completed: true)], repeatRule: .daily)
        let before = try store.backup().tasks
        try store.setCompleted(true, for: task.id)
        let after = try store.backup().tasks
        #expect(after.count == 2)
        let next = try #require(store.tasks().first { $0.id != task.id })
        #expect(next.plannedDate == "2026-10-30" && next.durationMinutes == 60)
        #expect(next.subtasks.first?.completed == false)
        try store.setCompleted(false, for: task.id)
        try store.setCompleted(true, for: task.id)
        #expect(try store.tasks().count == 2)
        // Timestamp changed on recompletion: use the current exact snapshot.
        try store.undoTasks(before: before, after: store.backup().tasks)
        #expect(try store.backup().tasks == before)
        #expect(try OrbitTaskStore(storeURL: url).backup().tasks == before)
        let backup = try OrbitBackup.decode(store.backup().encoded())
        #expect(backup.version == 3 && backup.tasks.first?.model().subtasks.count == 1)
        try store.deleteTask(for: task.id)
        try store.undoTasks(before: before, after: [])
        #expect(try store.backup().tasks == before)
        try store.renameTask(title: "Changed", for: task.id)
        #expect(throws: BackupError.self) { try store.undoTasks(before: [], after: before) }
    }
    @Test func completionFailureRollsBackWholeSelection() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("store"))
        let a = try store.addTask(title: "OK", plannedDate: "2026-10-29", repeatRule: .daily)
        let b = try store.addTask(title: "End", plannedDate: "2199-12-31", repeatRule: .daily)
        let before = try store.backup().tasks
        #expect(throws: BackupError.self) { try store.setCompleted(true, for: [a.id, b.id]) }
        #expect(try store.backup().tasks == before)
    }
}
