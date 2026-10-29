import Foundation
import Testing
@testable import OrbitCore

@Suite("Tags and archive") @MainActor struct TagsArchiveTests {
    func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    @Test func tagsArchiveAndBackupPersist() throws {
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("one.store"))
        try store.saveTag(name: "Учёба")
        try store.saveTag(name: "Звонки")
        let ids = try store.tags().map(\.id)
        #expect(throws: BackupError.self) { try store.saveTag(name: "учёба") }
        let p = try store.addProject(name: "Work")
        let task = try store.addTask(title: "Tagged", projectID: p.id, tagIDs: ids)
        try store.saveTag(name: "Новое имя", id: ids[0])
        #expect(Set(task.tagIDs ?? []) == Set(ids))
        var search = TaskSearch(); search.tagID = ids[0]
        #expect(search.results(in: try store.tasks()).map(\.id) == [task.id])
        try store.setProjectArchived(true, id: p.id)
        #expect(p.isArchived)
        #expect(task.projectID == p.id && !task.isCompleted)
        let backup = try OrbitBackup.decode(store.backup().encoded())
        #expect(backup.version == 3 && backup.tags?.count == 2)
        let target = try OrbitTaskStore(storeURL: dir.appendingPathComponent("two.store"))
        #expect(try target.restore(backup).newTags == 2)
        #expect(try target.restore(backup).newTags == 0)
        let reopened = try OrbitTaskStore(storeURL: dir.appendingPathComponent("two.store"))
        #expect(try reopened.tasks().first?.tagIDs == task.tagIDs)
        #expect(try reopened.projects().first?.isArchived == true)
        try reopened.setProjectArchived(false, id: p.id)
        #expect(try reopened.projects().first?.isArchived == false)
        #expect(throws: BackupError.self) { try store.addTask(title: "Bad", tagIDs: [UUID()]) }
        #expect(try store.tasks().count == 1)
        try store.updateTask(id: task.id, title: task.title, plannedDate: nil, plannedTime: nil,
            durationMinutes: nil, projectID: p.id, deadlineDate: nil, reminderAt: nil, tagIDs: [])
        #expect(task.tagIDs == nil)
    }
    @Test("Actual v1 store and backup upgrade", .enabled(if: ProcessInfo.processInfo.environment["ORBIT_TAGS_FIXTURE"] != nil))
    func oldSchema() throws {
        let source = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ORBIT_TAGS_FIXTURE"]!)
        let dir = try directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil) {
            try FileManager.default.copyItem(at: file, to: dir.appendingPathComponent(file.lastPathComponent))
        }
        let expected = try OrbitBackup.decode(Data(contentsOf: dir.appendingPathComponent("expected.json")))
        #expect(expected.version == 1 && expected.tags == nil)
        let migrated = try OrbitTaskStore(storeURL: dir.appendingPathComponent("legacy.store"))
        #expect(try migrated.backup().tasks == expected.tasks)
        #expect(try migrated.backup().projects == expected.projects)
        #expect(try migrated.tags().isEmpty)
        try migrated.saveTag(name: "После обновления")
        let clean = try OrbitTaskStore(storeURL: dir.appendingPathComponent("restore.store"))
        _ = try clean.restore(expected)
        #expect(try clean.backup().tasks == expected.tasks)
        #expect(try OrbitTaskStore(storeURL: dir.appendingPathComponent("legacy.store")).tags().count == 1)
    }
}
