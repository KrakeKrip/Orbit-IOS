import Foundation
import Testing
@testable import OrbitCore

@Suite("Tag colors and deletion") @MainActor struct TagColorTests {
    @Test func colorAndDeletionPersist() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("store")
        let store = try OrbitTaskStore(storeURL: url)
        try store.saveTag(name: "Work", color: "blue")
        let tag = try #require(store.tags().first)
        let task = try store.addTask(title: "Keep me", tagIDs: [tag.id])
        let copy = try OrbitBackup.decode(store.backup().encoded())
        #expect(copy.tags?.first?.colorName == "blue")
        let reopened = try OrbitTaskStore(storeURL: url)
        #expect(try reopened.tags().first?.colorName == "blue")
        try store.deleteTag(id: tag.id)
        #expect(try store.tags().isEmpty)
        #expect(try store.tasks().count == 1)
        #expect((task.tagIDs ?? []).isEmpty)
        let disk = try OrbitTaskStore(storeURL: url)
        #expect(try disk.tags().isEmpty)
        #expect((try disk.tasks().first?.tagIDs ?? []).isEmpty)
    }
    @Test func oldBackupWithoutColorAndFailedRename() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("store"))
        try store.saveTag(name: "One", color: "blue")
        try store.saveTag(name: "Two", color: "green")
        let one = try #require(store.tags().first { $0.name == "One" })
        do { try store.saveTag(name: "Two", id: one.id, color: "pink"); Issue.record("Duplicate accepted") } catch { }
        #expect(one.name == "One" && one.colorName == "blue")
        let backup = try store.backup().encoded()
        var json = try #require(JSONSerialization.jsonObject(with: backup) as? [String: Any])
        var tags = try #require(json["tags"] as? [[String: Any]])
        for index in tags.indices { tags[index].removeValue(forKey: "colorName") }
        json["tags"] = tags
        let old = try OrbitBackup.decode(JSONSerialization.data(withJSONObject: json))
        #expect(old.tags?.allSatisfy { $0.colorName == nil } == true)
    }
}
