import Foundation

/// Read-only selection of tasks planned on one civil day.
/// No model mutations, no new identities: the same `OrbitTask` objects are
/// returned in the array's existing stable order. This is only a list slice —
/// overdue/deadline/recurrence buckets and calendar grids are out of scope.
public enum TaskDaySelection {

    /// Today's local Gregorian civil date (`YYYY-MM-DD`) for the given
    /// reference instant, through the accepted Gregorian-pinned adapter and
    /// the supplied calendar's time zone (system calendar by default).
    /// Read once per refresh by the caller; never persisted into tasks.
    public static func currentDay(
        from reference: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        TaskPlannedDate.civilDateString(from: reference, calendar: calendar)
    }

    /// A missed planning day, independent from a task's separate deadline.
    public static func isOverdue(_ task: OrbitTask, before day: String) -> Bool {
        guard !task.isCompleted, TaskPlannedDate.isValid(day),
              let planned = task.plannedDate, TaskPlannedDate.isValid(planned) else { return false }
        return planned < day
    }

    /// Tasks whose `plannedDate` equals `day`, same objects in the same order.
    /// Timed and untimed, open and completed tasks are all included — the UI
    /// splits open/completed. An invalid or nil day yields an empty result
    /// (nil day means the caller has no day context; selection requires an
    /// explicit valid civil date).
    public static func tasks(onDay day: String?, in tasks: [OrbitTask]) -> [OrbitTask] {
        guard let day, TaskPlannedDate.isValid(day) else { return [] }
        return tasks.filter { $0.plannedDate == day }
    }
}
