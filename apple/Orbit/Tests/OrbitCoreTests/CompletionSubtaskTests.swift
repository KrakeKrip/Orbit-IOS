import Foundation
import Testing
@testable import OrbitCore

@Suite("Parent completion") @MainActor struct CompletionSubtaskTests {
    @Test func completesChildrenAndUndoRestoresThem() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("store")
        let store = try OrbitTaskStore(storeURL: url)
        let task = try store.addTask(title: "Parent", subtasks: [TaskSubtask(title: "Child")])
        let before = try store.backup().tasks
        try store.setCompleted(true, for: [task.id])
        #expect(task.subtasks.allSatisfy { $0.completed })
        let after = try store.backup().tasks
        let reopened = try OrbitTaskStore(storeURL: url)
        #expect(try reopened.tasks().first?.subtasks.first?.completed == true)
        try store.undoTasks(before: before, after: after)
        #expect(try store.tasks().first?.subtasks.first?.completed == false)
    }
    @Test func successorStartsWithOpenChildren() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let store = try OrbitTaskStore(storeURL: dir.appendingPathComponent("store"))
        let task = try store.addTask(title: "Daily", plannedDate: "2026-10-30", subtasks: [TaskSubtask(title: "Child")], repeatRule: .daily)
        try store.setCompleted(true, for: task.id)
        #expect(task.subtasks.allSatisfy { $0.completed })
        let next = try #require(store.tasks().first { $0.id != task.id })
        #expect(next.subtasks.allSatisfy { !$0.completed })
    }
}
