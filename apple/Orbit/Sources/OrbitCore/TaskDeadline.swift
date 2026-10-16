import Foundation

public enum TaskDeadlineError: Error, Equatable {
    case invalid(String)
}

/// Deadlines are independent Gregorian civil days, never UTC instants.
/// A task is due through the whole selected day; completed tasks are not overdue.
public enum TaskDeadline {
    public static func validate(_ value: String?) throws {
        if let value, !TaskPlannedDate.isValid(value) { throw TaskDeadlineError.invalid(value) }
    }

    public static func isOverdue(_ deadline: String?, completed: Bool, today: String) -> Bool {
        guard !completed, let deadline, TaskPlannedDate.isValid(deadline),
              TaskPlannedDate.isValid(today) else { return false }
        return deadline < today
    }
}
