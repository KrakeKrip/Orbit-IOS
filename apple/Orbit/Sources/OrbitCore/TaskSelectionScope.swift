import Foundation

/// Scope of a selection session, re-evaluated against the live task objects.
/// A calendar includes its day (including overnight continuation) and the
/// overdue bucket exposed on that screen, within the optional project.
public enum TaskSelectionScope: Equatable {
    case all
    case project(UUID)
    case calendar(projectID: UUID?, day: String, today: String)

    public func tasks(in tasks: [OrbitTask]) -> [OrbitTask] {
        switch self {
        case .all: return tasks
        case .project(let id): return tasks.filter { $0.projectID == id }
        case .calendar(let projectID, let day, let today):
            guard TaskPlannedDate.isValid(day) else { return [] }
            let candidates = tasks.filter { projectID == nil || $0.projectID == projectID }
            let projection = TaskDayProjector.project(day: day, in: candidates)
            let dayIDs = Set(projection.untimedTaskIDs + projection.timedSegments.map(\.taskID))
            return candidates.filter { dayIDs.contains($0.id) || TaskDaySelection.isOverdue($0, before: today) }
        }
    }
}
