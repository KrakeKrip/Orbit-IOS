import Foundation

/// Read-only project counts. Completion and overdue planning are independent
/// of the optional deadline; no progress percentage is inferred.
public struct ProjectTaskSummary: Equatable {
    public private(set) var total = 0
    public private(set) var open = 0
    public private(set) var today = 0
    public private(set) var overdue = 0
    public private(set) var undated = 0

    public init() {}

    public static func grouped(tasks: [OrbitTask], today: String) -> [UUID: Self] {
        var result: [UUID: Self] = [:]
        for task in tasks {
            guard let id = task.projectID else { continue }
            var summary = result[id, default: Self()]
            summary.total += 1
            if !task.isCompleted {
                summary.open += 1
                if task.plannedDate == today, TaskPlannedDate.isValid(today) { summary.today += 1 }
                if TaskDaySelection.isOverdue(task, before: today) { summary.overdue += 1 }
                if task.plannedDate == nil { summary.undated += 1 }
            }
            result[id] = summary
        }
        return result
    }
}
