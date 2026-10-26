import Foundation
import Testing
@testable import OrbitCore

struct ProjectContextTests {
    @Test func countsDistinguishEmptyCompletedAndOpenPlanning() {
        let a = UUID(), b = UUID(), empty = UUID()
        let tasks = [
            OrbitTask(title: "Today", plannedDate: "2026-10-26", projectID: a),
            OrbitTask(title: "Missed", plannedDate: "2026-10-23", projectID: a),
            OrbitTask(title: "No date", projectID: a),
            OrbitTask(title: "Future", plannedDate: "2026-10-30", projectID: a),
            OrbitTask(title: "Done", completedAt: .now, plannedDate: "2026-10-23", projectID: a),
            OrbitTask(title: "All done", completedAt: .now, plannedDate: "2026-10-26", projectID: b),
            OrbitTask(title: "Outside", plannedDate: "2026-10-23")
        ]
        let summaries = ProjectTaskSummary.grouped(tasks: tasks, today: "2026-10-26")
        #expect(summaries[a]?.total == 5 && summaries[a]?.open == 4)
        #expect(summaries[a]?.today == 1 && summaries[a]?.overdue == 1 && summaries[a]?.undated == 1)
        #expect(summaries[b]?.total == 1 && summaries[b]?.open == 0 && summaries[b]?.overdue == 0)
        #expect(summaries[empty, default: ProjectTaskSummary()].total == 0)
        tasks[0].complete()
        let tomorrow = ProjectTaskSummary.grouped(tasks: tasks, today: "2026-10-27")
        #expect(tomorrow[a]?.open == 3 && tomorrow[a]?.today == 0 && tomorrow[a]?.overdue == 1)
    }

    @Test func projectScopeDoesNotLeakOtherFoldersAndRechecksMembership() {
        let a = UUID(), b = UUID()
        let one = OrbitTask(title: "A", projectID: a)
        let done = OrbitTask(title: "Done", completedAt: .now, projectID: a)
        let other = OrbitTask(title: "B", projectID: b)
        let all = [one, done, other, OrbitTask(title: "Unassigned")]
        #expect(TaskSelectionScope.project(UUID()).tasks(in: all).isEmpty)
        #expect(TaskSelectionScope.project(a).tasks(in: all).map(\.id) == [one.id, done.id])
        one.setProject(b)
        #expect(TaskSelectionScope.project(a).tasks(in: all).map(\.id) == [done.id])
    }

    @Test func calendarScopeIncludesShownDayOverdueAndOvernightOnlyInsideProject() {
        let a = UUID(), b = UUID()
        let today = OrbitTask(title: "Today", plannedDate: "2026-10-26", projectID: a)
        let missed = OrbitTask(title: "Missed", plannedDate: "2026-10-24", projectID: a)
        let overnightDone = OrbitTask(title: "Overnight", completedAt: .now, plannedDate: "2026-10-25",
            plannedTime: "23:30", durationMinutes: 90, projectID: a)
        let future = OrbitTask(title: "Future", plannedDate: "2026-10-30", projectID: a)
        let other = OrbitTask(title: "Other project", plannedDate: "2026-10-26", projectID: b)
        let noDate = OrbitTask(title: "No date", projectID: a)
        let scope = TaskSelectionScope.calendar(projectID: a, day: "2026-10-26", today: "2026-10-26")
        #expect(scope.tasks(in: [today, missed, overnightDone, future, other, noDate]).map(\.id)
            == [today.id, missed.id, overnightDone.id])
        #expect(scope.tasks(in: [future, other, noDate]).isEmpty)
        #expect(TaskSelectionScope.calendar(projectID: a, day: "invalid", today: "2026-10-26")
            .tasks(in: [today, missed]).isEmpty)
    }
}
