import Foundation

public struct TaskSubtask: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var completed: Bool
    public init(id: UUID = UUID(), title: String, completed: Bool = false) {
        self.id = id; self.title = title; self.completed = completed
    }
}

public enum TaskRepeat: String, Codable, CaseIterable, Sendable {
    case daily, weekdays, weekly, monthly
    public var title: String {
        switch self {
        case .daily: "Каждый день"
        case .weekdays: "По будням"
        case .weekly: "Каждую неделю"
        case .monthly: "Каждый месяц"
        }
    }
    public func next(after day: String) -> String? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar) else { return nil }
        var candidate = calendar.date(byAdding: self == .monthly ? .month : .day,
                                      value: self == .weekly ? 7 : 1, to: date)
        if self == .weekdays {
            while let d = candidate, [1, 7].contains(calendar.component(.weekday, from: d)) {
                candidate = calendar.date(byAdding: .day, value: 1, to: d)
            }
        }
        return candidate.map { TaskPlannedDate.civilDateString(from: $0, calendar: calendar) }.flatMap(TaskPlannedDate.validated)
    }
}

public enum TaskProductivity {
    public static func validate(subtasks: [TaskSubtask], repeatRule: TaskRepeat?, day: String?) throws {
        guard subtasks.count <= 100, Set(subtasks.map(\.id)).count == subtasks.count else {
            throw BackupError.invalid("Не больше 100 подзадач с уникальными идентификаторами.")
        }
        for subtask in subtasks { _ = try TaskTitle.validated(subtask.title) }
        if repeatRule != nil && day == nil { throw BackupError.invalid("Для повторения выберите дату.") }
    }
}
