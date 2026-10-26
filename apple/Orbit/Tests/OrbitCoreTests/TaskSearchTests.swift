import Foundation
import Testing
@testable import OrbitCore

@Suite("Task search") struct TaskSearchTests {
    @Test func unicodeAndFilters() {
        let project = UUID()
        let a = OrbitTask(title: "СЪЁМКА café", projectID: project)
        let b = OrbitTask(title: "Съёмка", completedAt: .now, plannedDate: "2026-10-27")
        var q = TaskSearch()
        q.text = "  съемка  "
        #expect(q.results(in: [a,b]).map(\.id) == [a.id,b.id])
        q.status = .completed
        #expect(q.results(in: [a,b]).map(\.id) == [b.id])
        q.status = .open; q.undatedOnly = true; q.projectID = project
        #expect(q.results(in: [a,b]).map(\.id) == [a.id])
        q.unassignedOnly = true
        #expect(q.results(in: [a,b]).isEmpty)
        q = TaskSearch(); q.text = "CAFE"
        #expect(q.results(in: [a,b]).map(\.id) == [a.id])
        q.text = "нет такой задачи"
        #expect(q.results(in: [a,b]).isEmpty)
        q.text = " \n "
        #expect(q.results(in: [a,b]).count == 2)
    }
    @Test func thousandTasksAndLiveChanges() {
        let tasks = (0..<1000).map { OrbitTask(title: "Задача \($0)") }
        var q = TaskSearch(); q.text = "Задача 999"
        #expect(q.results(in: tasks).map(\.id) == [tasks[999].id])
        q.status = .open
        tasks[999].complete()
        #expect(q.results(in: tasks).isEmpty)
        q.status = .completed
        #expect(q.results(in: tasks).count == 1)
    }
}
