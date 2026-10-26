import Foundation

public struct OrbitBackup: Codable, Equatable {
    public var format = "orbit-backup"
    public var version = 2
    public var exportedAt: Date
    public var projects: [Project]
    public var tasks: [Task]
    public var tags: [Tag]?
    public struct Tag: Codable, Equatable {
        public var id: UUID
        public var name: String
        public var createdAt: Date
        public init(_ value: OrbitTag) { id = value.id; name = value.name; createdAt = value.createdAt }
        public func model() -> OrbitTag { OrbitTag(id: id, name: name, createdAt: createdAt) }
    }
    public struct Project: Codable, Equatable {
        public var id: UUID
        public var name: String
        public var createdAt: Date
        public var archivedAt: Date?
        public init(_ value: OrbitProject) { id = value.id; name = value.name; createdAt = value.createdAt; archivedAt = value.archivedAt }
        public func model() -> OrbitProject { OrbitProject(id: id, name: name, createdAt: createdAt, archivedAt: archivedAt) }
    }
    public struct Task: Codable, Equatable {
        public var id: UUID
        public var projectID: UUID?
        public var tagIDs: [UUID]?
        public var title: String
        public var createdAt: Date
        public var completedAt: Date?
        public var plannedDate: String?
        public var plannedTime: String?
        public var durationMinutes: Int?
        public var deadlineDate: String?
        public var reminderAt: Date?
        public init(_ t: OrbitTask) {
            tagIDs = t.tagIDs
            id = t.id; projectID = t.projectID; title = t.title; createdAt = t.createdAt
            completedAt = t.completedAt; plannedDate = t.plannedDate; plannedTime = t.plannedTime
            durationMinutes = t.durationMinutes; deadlineDate = t.deadlineDate; reminderAt = t.reminderAt
        }
        public func model() -> OrbitTask {
            OrbitTask(id: id, title: title, createdAt: createdAt, completedAt: completedAt,
                      plannedDate: plannedDate, plannedTime: plannedTime, durationMinutes: durationMinutes,
                      projectID: projectID, deadlineDate: deadlineDate, reminderAt: reminderAt, tagIDs: tagIDs)
        }
    }
    public init(projects: [OrbitProject], tasks: [OrbitTask], tags: [OrbitTag] = [], now: Date = .now) {
        self.tags = tags.map(Tag.init)
        exportedAt = now; self.projects = projects.map(Project.init); self.tasks = tasks.map(Task.init)
    }
    public static let maximumBytes = 20 * 1024 * 1024
    public static func decode(_ data: Data) throws -> Self {
        guard data.count <= maximumBytes else { throw BackupError.invalid("Файл больше 20 МБ.") }
        let value: Self
        do { value = try JSONDecoder().decode(Self.self, from: data) }
        catch { throw BackupError.invalid("Не удалось прочитать файл резервной копии.") }
        try value.validate()
        return value
    }
    public func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw BackupError.invalid("Копия превышает 20 МБ.") }
        return data
    }
    public func validate() throws {
        guard format == "orbit-backup", (version == 1 || version == 2) else { throw BackupError.invalid("Формат или версия копии не поддерживается.") }
        guard tasks.count <= 100_000, projects.count <= 10_000,
              Set(tasks.map(\.id)).count == tasks.count, Set(projects.map(\.id)).count == projects.count else {
            throw BackupError.invalid("В файле повторяются идентификаторы или слишком много записей.")
        }
        let tagIDs = Set((tags ?? []).map(\.id))
        guard tagIDs.count == (tags ?? []).count, tagIDs.count <= 10_000 else { throw BackupError.invalid("Некорректный список тегов.") }
        for tag in tags ?? [] { _ = try ProjectName.validated(tag.name) }
        let ids = Set(projects.map(\.id))
        for project in projects { _ = try ProjectName.validated(project.name) }
        for task in tasks {
            guard Set(task.tagIDs ?? []).isSubset(of: tagIDs), Set(task.tagIDs ?? []).count == (task.tagIDs ?? []).count else { throw BackupError.invalid("Нарушены связи тегов.") }
            _ = try TaskTitle.validated(task.title)
            guard task.projectID == nil || ids.contains(task.projectID!),
                  task.plannedDate == nil || TaskPlannedDate.isValid(task.plannedDate!),
                  TaskTimeInterval.isCompletePair(time: task.plannedTime, durationMinutes: task.durationMinutes) else {
                throw BackupError.invalid("Нарушены связи или дата задачи.")
            }
            if let time = task.plannedTime, let duration = task.durationMinutes {
                guard let day = task.plannedDate,
                      TaskTimeInterval.end(plannedDate: day, plannedTime: time, durationMinutes: duration) != nil else {
                    throw BackupError.invalid("Некорректный интервал задачи.")
                }
            }
            try TaskDeadline.validate(task.deadlineDate)
            // Existing past reminders are valid history; scheduler will not deliver them.
            try TaskReminder.validate(task.reminderAt, now: .distantPast)
        }
    }
    public struct Plan: Equatable {
        public let newTags: Int
        public let newProjects: Int
        public let newTasks: Int
        public let unchanged: Int
    }
    public func plan(against current: Self) throws -> Plan {
        try validate(); try current.validate()
        let currentTags = Dictionary(uniqueKeysWithValues: (current.tags ?? []).map { ($0.id, $0) })
        for tag in tags ?? [] { if let old = currentTags[tag.id], old != tag { throw BackupError.conflict } }
        let newTags = (tags ?? []).filter { currentTags[$0.id] == nil }.count
        let currentProjects = Dictionary(uniqueKeysWithValues: current.projects.map { ($0.id, $0) })
        let currentTasks = Dictionary(uniqueKeysWithValues: current.tasks.map { ($0.id, $0) })
        for p in projects { if let old = currentProjects[p.id], old != p { throw BackupError.conflict } }
        for t in tasks { if let old = currentTasks[t.id], old != t { throw BackupError.conflict } }
        let p = projects.filter { currentProjects[$0.id] == nil }.count
        let t = tasks.filter { currentTasks[$0.id] == nil }.count
        return Plan(newTags: newTags, newProjects: p, newTasks: t, unchanged: projects.count + tasks.count + (tags ?? []).count - p - t - newTags)
    }
}

public enum BackupError: LocalizedError {
    case invalid(String), conflict
    public var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        case .conflict: "В копии есть изменённые версии существующих записей. Восстановление остановлено: текущие данные не изменены."
        }
    }
}
