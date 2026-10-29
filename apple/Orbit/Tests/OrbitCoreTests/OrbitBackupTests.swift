import Foundation
import Testing
@testable import OrbitCore

@Suite("Backup") @MainActor struct OrbitBackupTests {
    func url() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("test.store")
    }
    @Test func roundTripAndIdempotentRestore() throws {
        let sourceURL = try url(), targetURL = try url()
        defer {
            try? FileManager.default.removeItem(at: sourceURL.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: targetURL.deletingLastPathComponent())
        }
        let source = try OrbitTaskStore(storeURL: sourceURL)
        let project = try source.addProject(name: "Учёба")
        let task = try source.addTask(title: "Детали 🪐", plannedDate: "2026-10-26", plannedTime: "23:30", durationMinutes: 90,
                                     projectID: project.id, deadlineDate: "2026-10-30", reminderAt: Date(timeIntervalSince1970: 2000000000))
        try source.setCompleted(true, for: task.id)
        let copy = try OrbitBackup.decode(source.backup().encoded())
        let target = try OrbitTaskStore(storeURL: targetURL)
        let local = try target.addTask(title: "Keep me")
        let plan = try target.restore(copy)
        #expect(plan.newTasks == 1 && plan.newProjects == 1)
        #expect(try target.restore(copy).newTasks == 0)
        let restored = try OrbitTaskStore(storeURL: targetURL).backup()
        #expect(restored.tasks.contains(copy.tasks[0]))
        #expect(restored.tasks.contains { $0.id == local.id })
        #expect(restored.projects == copy.projects)
    }
    @Test func rejectsInvalidAndConflictingFilesWithoutWrites() throws {
        let storeURL = try url()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }
        let store = try OrbitTaskStore(storeURL: storeURL)
        _ = try store.addTask(title: "Original")
        let original = try store.backup()
        var conflict = original; conflict.tasks[0].title = "Changed"
        #expect(throws: BackupError.self) { try store.restore(conflict) }
        #expect(try store.backup().tasks == original.tasks)
        var duplicate = original; duplicate.tasks += duplicate.tasks
        #expect(throws: BackupError.self) { try duplicate.validate() }
        var broken = original; broken.tasks[0].projectID = UUID()
        #expect(throws: BackupError.self) { try broken.validate() }
        broken = original; broken.tasks[0].plannedTime = "12:00"
        #expect(throws: BackupError.self) { try broken.validate() }
        var future = original; future.version = 4
        #expect(throws: BackupError.self) { try future.validate() }
        #expect(throws: BackupError.self) { try OrbitBackup.decode(Data("garbage".utf8)) }
        #expect(throws: BackupError.self) { try OrbitBackup.decode(Data(repeating: 0, count: OrbitBackup.maximumBytes + 1)) }
        #expect(try OrbitTaskStore(storeURL: storeURL).backup().tasks == original.tasks)
    }
    @Test func supportsLegacyShortIntervalsAndEmptySnapshot() throws {
        let task = OrbitTask(title: "Legacy", plannedDate: "2026-10-26", plannedTime: "09:00", durationMinutes: 1)
        let copy = OrbitBackup(projects: [], tasks: [task])
        #expect(try OrbitBackup.decode(copy.encoded()) == copy)
        let empty = OrbitBackup(projects: [], tasks: [])
        #expect(try OrbitBackup.decode(empty.encoded()) == empty)
    }
}
