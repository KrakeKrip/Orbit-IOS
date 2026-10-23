import Foundation
import SwiftData
import Testing
@testable import OrbitCore

@Suite("Atomic task editor")
struct TaskEditorTests {
    @Test @MainActor func wholeDraftPersistsAndKeepsIdentity() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let store = try OrbitTaskStore(storeURL: url)
        let task = try store.addTask(title: "Before")
        let project = try store.addProject(name: "Project")
        let id = task.id, created = task.createdAt
        let reminder = Date(timeIntervalSince1970: floor(Date.now.timeIntervalSince1970) + 3600)
        try store.updateTask(id: id, title: " After ", plannedDate: "2026-10-23", plannedTime: "23:30",
                             durationMinutes: 120, projectID: project.id, deadlineDate: "2026-10-24",
                             reminderAt: reminder, completed: true)
        let reopened = try OrbitTaskStore(storeURL: url)
        let saved = try #require(reopened.tasks().first)
        #expect(saved.id == id && saved.createdAt == created && saved.title == "After")
        #expect(saved.projectID == project.id && saved.deadlineDate == "2026-10-24" && saved.reminderAt == reminder)
        #expect(saved.plannedTime == "23:30" && saved.durationMinutes == 120 && saved.isCompleted)
        try reopened.updateTask(id: id, title: "After", plannedDate: nil, plannedTime: nil,
                                durationMinutes: nil, projectID: nil, deadlineDate: saved.deadlineDate,
                                reminderAt: nil, completed: false)
        #expect(saved.plannedDate == nil && saved.plannedTime == nil && saved.durationMinutes == nil)
        #expect(!saved.isCompleted && saved.deadlineDate == "2026-10-24")
    }

    @Test @MainActor func invalidDraftDoesNotPartiallyWrite() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let store = try OrbitTaskStore(storeURL: url)
        let task = try store.addTask(title: "Original", plannedDate: "2026-10-23")
        for field in 0..<4 {
            do {
                try store.updateTask(id: task.id, title: "Changed", plannedDate: "2026-10-24",
                                     plannedTime: "09:00", durationMinutes: field == 0 ? 0 : 30,
                                     projectID: field == 1 ? UUID() : nil,
                                     deadlineDate: field == 2 ? "bad" : nil,
                                     reminderAt: field == 3 ? Date(timeIntervalSince1970: 0) : nil,
                                     completed: true)
                Issue.record("Invalid draft accepted")
            } catch { }
            #expect(task.title == "Original" && task.plannedDate == "2026-10-23" && !task.isCompleted)
            let disk = try OrbitTaskStore(storeURL: url)
            #expect(try disk.tasks().first?.title == "Original")
        }
    }

    @Test @MainActor func preservesUnchangedLegacyIntervalAndPastReminder() throws {
        let dir = try TempDir.make(); defer { TempDir.remove(dir) }
        let url = dir.appendingPathComponent("Orbit.store")
        let container = try ModelContainer(for: OrbitTask.self, OrbitProject.self, configurations: ModelConfiguration(url: url, cloudKitDatabase: .none))
        let context = ModelContext(container)
        let past = Date(timeIntervalSince1970: 100)
        let task = OrbitTask(title: "Legacy", plannedDate: "2026-10-23", plannedTime: "09:00", durationMinutes: 3, reminderAt: past)
        context.insert(task); try context.save()
        let store = try OrbitTaskStore(storeURL: url)
        try store.updateTask(id: task.id, title: "Renamed", plannedDate: "2026-10-23", plannedTime: "09:00",
                             durationMinutes: 3, projectID: nil, deadlineDate: nil, reminderAt: past)
        let saved = try #require(store.tasks().first)
        #expect(saved.durationMinutes == 3 && saved.reminderAt == past && saved.title == "Renamed")
        do {
            try store.updateTask(id: task.id, title: "Invalid legacy move", plannedDate: "2026-10-24", plannedTime: "09:00",
                                 durationMinutes: 3, projectID: nil, deadlineDate: nil, reminderAt: past)
            Issue.record("Legacy duration was written to a new schedule")
        } catch { }
        #expect(saved.title == "Renamed" && saved.plannedDate == "2026-10-23")
    }
}
