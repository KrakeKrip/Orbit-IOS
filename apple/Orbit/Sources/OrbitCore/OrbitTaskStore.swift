import Foundation
import SwiftData

@MainActor
public final class OrbitTaskStore {
    public let storeURL: URL

    private let container: ModelContainer
    private let context: ModelContext

    public init(storeURL: URL) throws {
        self.storeURL = storeURL
        let configuration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)
        self.container = try ModelContainer(for: OrbitTask.self, OrbitProject.self, OrbitTag.self, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context
    }

    /// Compare-and-restore only the tasks changed by one action. Never overwrite newer work.
    public func undoTasks(before: [OrbitBackup.Task], after: [OrbitBackup.Task]) throws {
        let old = Dictionary(uniqueKeysWithValues: before.map { ($0.id, $0) })
        let new = Dictionary(uniqueKeysWithValues: after.map { ($0.id, $0) })
        let changed = Set(old.keys).union(new.keys).filter { old[$0] != new[$0] }
        let currentModels = try tasks()
        let current = Dictionary(uniqueKeysWithValues: currentModels.map { ($0.id, OrbitBackup.Task($0)) })
        guard changed.allSatisfy({ current[$0] == new[$0] }) else { throw BackupError.conflict }
        do {
            for id in changed {
                let model = currentModels.first { $0.id == id }
                if let snapshot = old[id] {
                    if let model { model.restoreSnapshot(snapshot) } else { context.insert(snapshot.model()) }
                } else if let model { context.delete(model) }
            }
            try context.save()
        } catch { context.rollback(); throw error }
    }

    public func backup() throws -> OrbitBackup {
        OrbitBackup(projects: try projects(), tasks: try tasks(), tags: try tags())
    }

    public func restore(_ backup: OrbitBackup) throws -> OrbitBackup.Plan {
        let current = try self.backup()
        let plan = try backup.plan(against: current)
        // Validate actual SwiftData materialization in an isolated store first.
        let staging = try ModelContainer(for: OrbitTask.self, OrbitProject.self, OrbitTag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let stagedContext = ModelContext(staging)
        stagedContext.autosaveEnabled = false
        for tag in backup.tags ?? [] { stagedContext.insert(tag.model()) }
        for project in backup.projects { stagedContext.insert(project.model()) }
        for task in backup.tasks { stagedContext.insert(task.model()) }
        try stagedContext.save()
        let projects = Set(current.projects.map(\.id)), tasks = Set(current.tasks.map(\.id))
        let tagIDs = Set((current.tags ?? []).map(\.id))
        do {
            for tag in backup.tags ?? [] where !tagIDs.contains(tag.id) { context.insert(tag.model()) }
            for project in backup.projects where !projects.contains(project.id) { context.insert(project.model()) }
            for task in backup.tasks where !tasks.contains(task.id) { context.insert(task.model()) }
            try context.save()
        } catch { context.rollback(); throw error }
        return plan
    }

    public func tags() throws -> [OrbitTag] {
        try context.fetch(FetchDescriptor<OrbitTag>()).sorted { ($0.name, $0.id) < ($1.name, $1.id) }
    }
    public func saveTag(name: String, id: UUID? = nil, color: String? = nil) throws {
        if let color, !OrbitTag.colors.contains(color) { throw BackupError.invalid("Неизвестный цвет тега.") }
        let name = try ProjectName.validated(name)
        let all = try tags()
        guard !all.contains(where: { $0.id != id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) else {
            throw BackupError.invalid("Тег с таким названием уже есть.")
        }
        if let id {
            guard let tag = all.first(where: { $0.id == id }) else { throw BackupError.invalid("Тег не найден.") }
            tag.rename(name)
            if let color { tag.setColor(color) }
        } else { context.insert(OrbitTag(name: name, colorName: color ?? "coral")) }
        do { try context.save() } catch { context.rollback(); throw error }
    }
    public func deleteTag(id: UUID) throws {
        guard let tag = try tags().first(where: { $0.id == id }) else { throw BackupError.invalid("Тег не найден.") }
        do {
            for task in try tasks() where (task.tagIDs ?? []).contains(id) {
                task.setTags((task.tagIDs ?? []).filter { $0 != id })
            }
            context.delete(tag)
            try context.save()
        } catch { context.rollback(); throw error }
    }
    private func validateTags(_ ids: [UUID]) throws {
        let available = Set(try tags().map(\.id))
        guard Set(ids).count == ids.count, Set(ids).isSubset(of: available) else { throw BackupError.invalid("Тег не найден или указан повторно.") }
    }
    public func setProjectArchived(_ archived: Bool, id: UUID) throws {
        guard let project = try projects().first(where: { $0.id == id }) else { throw OrbitProjectStoreError.projectNotFound(id: id) }
        project.setArchived(archived)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    /// Stable local order, independent of store collation; duplicate names allowed.
    public func projects() throws -> [OrbitProject] {
        let fetched = try context.fetch(FetchDescriptor<OrbitProject>())
        return fetched.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }

    @discardableResult
    public func addProject(name rawName: String, now: Date = .now) throws -> OrbitProject {
        let name = try ProjectName.validated(rawName)
        let project = OrbitProject(name: name, createdAt: now)
        context.insert(project)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return project
    }

    /// Changes only the name. Validation precedes mutation; identical is a no-op.
    @discardableResult
    public func renameProject(name rawName: String, for id: UUID) throws -> OrbitProject {
        let name = try ProjectName.validated(rawName)
        let descriptor = FetchDescriptor<OrbitProject>(predicate: #Predicate { $0.id == id })
        guard let project = try context.fetch(descriptor).first else {
            throw OrbitProjectStoreError.projectNotFound(id: id)
        }
        if project.name != name {
            project.setName(name)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        return project
    }

    public func tasks() throws -> [OrbitTask] {
        let fetched = try context.fetch(FetchDescriptor<OrbitTask>())
        // Explicit stable order (createdAt, then id) independent of store-level collation.
        return fetched.sorted { ($0.createdAt, $0.id) < ($1.createdAt, $1.id) }
    }

    /// NATIVE-ADD-001/ADD-003: creates one task together with its optional
    /// civil planned date and optional time interval in a single save.
    /// Backwards compatible: existing title/now and title/now/date calls
    /// keep working — an undated task and a dated untimed task stay valid
    /// (plannedDate/plannedTime/durationMinutes default to nil; a nil/nil
    /// pair means no interval). The whole candidate is validated before any
    /// context mutation: `TaskTitle.validated`, `TaskPlannedDate.isValid`,
    /// `TaskTimeInterval.isCompletePair` (a partial pair is never silently
    /// ignored), `isValidTime`, `isWritableDuration` (write minimum
    /// 5...1440 — a minimum, not a step-of-5 rule: 6/7 stay valid) and, for
    /// a timed candidate, the presence of an explicit date (never implicitly
    /// "today") plus the derived end through `TaskTimeInterval.end`. Existing
    /// error cases are reused, no new validators/calendar/UTC/rounding. On
    /// success exactly one explicit `context.save()` persists one row with
    /// one UUID/createdAt and nil completion — never an add-then-edit
    /// sequence or intermediate saves — with the existing rollback
    /// rethrowing a save failure. The derived end is never stored; the date
    /// is always an explicit civil string from the caller.
    @discardableResult
    public func addTask(
        title rawTitle: String,
        now: Date = .now,
        plannedDate: String? = nil,
        plannedTime: String? = nil,
        durationMinutes: Int? = nil,
        projectID: UUID? = nil,
        deadlineDate: String? = nil,
        reminderAt: Date? = nil,
        tagIDs: [UUID] = [],
        subtasks: [TaskSubtask] = [], repeatRule: TaskRepeat? = nil
    ) throws -> OrbitTask {
        let title = try TaskTitle.validated(rawTitle)
        try TaskProductivity.validate(subtasks: subtasks, repeatRule: repeatRule, day: plannedDate)
        try validateTags(tagIDs)
        if let plannedDate, !TaskPlannedDate.isValid(plannedDate) {
            throw TaskPlannedDateError.invalid(plannedDate)
        }
        if !TaskTimeInterval.isCompletePair(time: plannedTime, durationMinutes: durationMinutes) {
            throw TaskTimeIntervalError.incompletePair(time: plannedTime, durationMinutes: durationMinutes)
        }
        if let plannedTime, !TaskTimeInterval.isValidTime(plannedTime) {
            throw TaskTimeIntervalError.invalidTime(plannedTime)
        }
        if let durationMinutes {
            if !TaskTimeInterval.isValidDuration(durationMinutes) {
                throw TaskTimeIntervalError.invalidDuration(durationMinutes)
            }
            if !TaskTimeInterval.isWritableDuration(durationMinutes) {
                throw TaskTimeIntervalError.invalidDuration(durationMinutes)
            }
        }
        if let plannedTime, let durationMinutes {
            guard let plannedDate else {
                throw TaskTimeIntervalError.missingDate
            }
            guard TaskTimeInterval.end(
                plannedDate: plannedDate,
                plannedTime: plannedTime,
                durationMinutes: durationMinutes
            ) != nil else {
                throw TaskTimeIntervalError.endOutOfRange
            }
        }
        try TaskReminder.validate(reminderAt, now: now)
        try TaskDeadline.validate(deadlineDate)
        try validateProject(projectID)
        let task = OrbitTask(
            title: title,
            createdAt: now,
            plannedDate: plannedDate,
            plannedTime: plannedTime,
            durationMinutes: durationMinutes,
            projectID: projectID,
            deadlineDate: deadlineDate,
            reminderAt: reminderAt,
            tagIDs: tagIDs.isEmpty ? nil : tagIDs.sorted { $0.uuidString < $1.uuidString }
        )
        try task.setProductivity(subtasks, repeatRule)
        context.insert(task)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return task
    }

    /// Validates the entire editor draft before mutating, then commits once.
    /// Identity, creation time and unchanged legacy intervals/reminders survive.
    public func updateTask(id: UUID, title rawTitle: String, plannedDate: String?,
                           plannedTime: String?, durationMinutes: Int?, projectID: UUID?,
                           deadlineDate: String?, reminderAt: Date?, completed: Bool? = nil, tagIDs: [UUID]? = nil,
                           now: Date = .now, subtasks: [TaskSubtask]? = nil, repeatRule: TaskRepeat? = nil, updateRepeat: Bool = false) throws {
        let title = try TaskTitle.validated(rawTitle)
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else { throw OrbitStoreError.taskNotFound(id: id) }
        if let plannedDate, !TaskPlannedDate.isValid(plannedDate) { throw TaskPlannedDateError.invalid(plannedDate) }
        guard TaskTimeInterval.isCompletePair(time: plannedTime, durationMinutes: durationMinutes) else {
            throw TaskTimeIntervalError.incompletePair(time: plannedTime, durationMinutes: durationMinutes)
        }
        if let plannedTime, !TaskTimeInterval.isValidTime(plannedTime) { throw TaskTimeIntervalError.invalidTime(plannedTime) }
        if let durationMinutes {
            guard TaskTimeInterval.isWritableDuration(durationMinutes) ||
                (durationMinutes == task.durationMinutes && plannedDate == task.plannedDate && plannedTime == task.plannedTime && TaskTimeInterval.isValidDuration(durationMinutes)) else {
                throw TaskTimeIntervalError.invalidDuration(durationMinutes)
            }
        }
        if let plannedTime, let durationMinutes {
            guard let plannedDate else { throw TaskTimeIntervalError.missingDate }
            guard TaskTimeInterval.end(plannedDate: plannedDate, plannedTime: plannedTime, durationMinutes: durationMinutes) != nil else {
                throw TaskTimeIntervalError.endOutOfRange
            }
        }
        try validateProject(projectID)
        try TaskDeadline.validate(deadlineDate)
        if reminderAt != task.reminderAt { try TaskReminder.validate(reminderAt, now: now) }
        if reminderAt != nil && task.isCompleted && completed != false && reminderAt != task.reminderAt {
            throw TaskReminderError.completedTask
        }
        if let tagIDs { try validateTags(tagIDs) }
        let rule = updateRepeat ? repeatRule : task.repeatRule
        try TaskProductivity.validate(subtasks: subtasks ?? task.subtasks, repeatRule: rule, day: plannedDate)
        do {
        try task.setProductivity(subtasks ?? task.subtasks, rule)
        task.setTitle(title)
        task.setPlannedDate(plannedDate)
        task.setPlannedInterval(plannedTime: plannedTime, durationMinutes: durationMinutes)
        task.setProject(projectID)
        if let tagIDs { task.setTags(tagIDs) }
        task.setDeadlineDate(deadlineDate)
        task.setReminderAt(reminderAt)
        if let completed {
            if completed { try completeWithRepeat(task, at: now) } else { task.reopen() }
        }
        try context.save()
        } catch { context.rollback(); throw error }
    }

    /// A reminder is independent of scheduling. Past stored values remain readable.
    public func setReminderAt(_ value: Date?, for id: UUID, now: Date = .now) throws {
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else { throw OrbitStoreError.taskNotFound(id: id) }
        guard task.reminderAt != value else { return }
        try TaskReminder.validate(value, now: now)
        if value != nil && task.isCompleted { throw TaskReminderError.completedTask }
        task.setReminderAt(value)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    /// Changes only the deadline. Validation before mutation; identical is a no-op.
    public func setDeadlineDate(_ value: String?, for id: UUID) throws {
        try TaskDeadline.validate(value)
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        guard task.deadlineDate != value else { return }
        task.setDeadlineDate(value)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    private func validateProject(_ id: UUID?) throws {
        guard let id else { return }
        let descriptor = FetchDescriptor<OrbitProject>(predicate: #Predicate { $0.id == id })
        guard try context.fetch(descriptor).first != nil else {
            throw OrbitProjectStoreError.projectNotFound(id: id)
        }
    }

    public func setProject(_ projectID: UUID?, for id: UUID) throws {
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        try validateProject(projectID)
        guard task.projectID != projectID else { return }
        task.setProject(projectID)
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    public func setCompleted(_ isCompleted: Bool, for id: UUID, at date: Date = .now) throws {
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        do {
            if isCompleted { try completeWithRepeat(task, at: date) } else { task.reopen() }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func completeWithRepeat(_ task: OrbitTask, at date: Date) throws {
        guard !task.isCompleted else { return }
        if let rule = task.repeatRule, let day = task.plannedDate, task.nextOccurrenceID == nil {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = .current
            let today = TaskPlannedDate.civilDateString(from: date, calendar: calendar)
            var candidate = rule.next(after: day)
            while let value = candidate, value <= today { candidate = rule.next(after: value) }
            guard let next = candidate else { throw BackupError.invalid("Повтор выходит за пределы календаря.") }
            var nextReminder: Date?
            if let reminder = task.reminderAt,
               let oldDay = TaskPlannedDate.date(fromCivilDateString: day, calendar: calendar),
               let newDay = TaskPlannedDate.date(fromCivilDateString: next, calendar: calendar),
               let days = calendar.dateComponents([.day], from: oldDay, to: newDay).day {
                nextReminder = calendar.date(byAdding: .day, value: days, to: reminder)
            }
            if let time = task.plannedTime, let duration = task.durationMinutes,
               TaskTimeInterval.end(plannedDate: next, plannedTime: time, durationMinutes: duration) == nil {
                throw TaskTimeIntervalError.endOutOfRange
            }
            let successor = OrbitTask(title: task.title, createdAt: date, plannedDate: next,
                plannedTime: task.plannedTime, durationMinutes: task.durationMinutes,
                projectID: task.projectID, reminderAt: nextReminder, tagIDs: task.tagIDs)
            try successor.setProductivity(task.subtasks.map { TaskSubtask(title: $0.title) }, rule)
            context.insert(successor)
            task.setNextOccurrence(successor.id)
        }
        try task.setProductivity(task.subtasks.map { item in
            var completed = item
            completed.completed = true
            return completed
        }, task.repeatRule)
        task.complete(at: date)
    }

    /// Validate every UUID before mutation, then save the whole selection once.
    public func setCompleted(_ isCompleted: Bool, for ids: [UUID], at date: Date = .now) throws {
        let targets = try selectedTasks(ids).filter { $0.isCompleted != isCompleted }
        guard !targets.isEmpty else { return }
        do {
            for task in targets {
                if isCompleted { try completeWithRepeat(task, at: date) } else { task.reopen() }
            }
            try context.save()
        }
        catch { context.rollback(); throw error }
    }

    public func deleteTasks(for ids: [UUID]) throws {
        let targets = try selectedTasks(ids)
        guard !targets.isEmpty else { return }
        for task in targets { context.delete(task) }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    private func selectedTasks(_ ids: [UUID]) throws -> [OrbitTask] {
        try Set(ids).sorted { $0.uuidString < $1.uuidString }.map { id in
            let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
            guard let task = try context.fetch(descriptor).first else { throw OrbitStoreError.taskNotFound(id: id) }
            return task
        }
    }

    /// NATIVE-EDIT-001: renames one task in a single explicit save. The
    /// accepted `TaskTitle.validated` check runs before any mutation; an
    /// unknown UUID throws the existing `OrbitStoreError.taskNotFound`. Only
    /// `title` changes — id, createdAt, completion, planned date and interval
    /// are never touched. A normalized identical title is a no-op without
    /// `context.save()`; a real change is one explicit save with the existing
    /// rollback rethrowing a save failure. The calling UI (later EDIT task)
    /// uses this store operation, not the raw model setter.
    @discardableResult
    public func renameTask(title rawTitle: String, for id: UUID) throws -> OrbitTask {
        let title = try TaskTitle.validated(rawTitle)
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        if task.title != title {
            task.setTitle(title)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
        return task
    }

    /// NATIVE-EDIT-001: hard-deletes exactly one task of the local prototype
    /// store in a single explicit save. An unknown UUID throws the existing
    /// `OrbitStoreError.taskNotFound`; only this task's row is removed — every
    /// other task keeps all of its fields. No soft delete/archive/history and
    /// no schema change; the calling UI (later EDIT task) is responsible for
    /// asking the user for confirmation with the visible title before
    /// invoking this.
    public func deleteTask(for id: UUID) throws {
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        context.delete(task)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Atomic date move: validate every target and derived end before any
    /// mutation. Absolute reminders/deadlines and intervals remain unchanged.
    public func rescheduleTasks(_ ids: [UUID], to day: String) throws {
        guard TaskPlannedDate.isValid(day) else { throw TaskPlannedDateError.invalid(day) }
        let targets = try selectedTasks(ids)
        for task in targets {
            if let time = task.plannedTime, let duration = task.durationMinutes,
               TaskTimeInterval.end(plannedDate: day, plannedTime: time, durationMinutes: duration) == nil {
                throw TaskTimeIntervalError.endOutOfRange
            }
        }
        let changed = targets.filter { $0.plannedDate != day }
        guard !changed.isEmpty else { return }
        for task in changed { task.setPlannedDate(day) }
        do { try context.save() }
        catch { context.rollback(); throw error }
    }

    /// A cross-column timeline move writes its complete schedule atomically.
    /// Reminder/deadline/completion/project/order are untouched.
    public func setPlannedSchedule(date: String, time: String, duration: Int, for id: UUID) throws {
        guard TaskPlannedDate.isValid(date) else { throw TaskPlannedDateError.invalid(date) }
        guard TaskTimeInterval.isValidTime(time) else { throw TaskTimeIntervalError.invalidTime(time) }
        guard TaskTimeInterval.isWritableDuration(duration) else { throw TaskTimeIntervalError.invalidDuration(duration) }
        guard TaskTimeInterval.end(plannedDate: date, plannedTime: time, durationMinutes: duration) != nil else {
            throw TaskTimeIntervalError.endOutOfRange
        }
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else { throw OrbitStoreError.taskNotFound(id: id) }
        guard task.plannedDate != date || task.plannedTime != time || task.durationMinutes != duration else { return }
        task.setPlannedDate(date)
        task.setPlannedInterval(plannedTime: time, durationMinutes: duration)
        do { try context.save() } catch { context.rollback(); throw error }
    }

    /// Assigns, changes or clears (`nil`) the civil planned date of one task.
    /// Invalid values are rejected before any mutation; completion, title, id
    /// and list order are never touched, and tasks with a date stay in the Inbox.
    /// Clearing the date also clears the time interval in the same save; a date
    /// change keeps an existing interval only when the resulting derived end
    /// stays inside the product calendar range.
    public func setPlannedDate(_ plannedDate: String?, for id: UUID) throws {
        if let plannedDate, !TaskPlannedDate.isValid(plannedDate) {
            throw TaskPlannedDateError.invalid(plannedDate)
        }
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        if let plannedDate,
            let time = task.plannedTime, let duration = task.durationMinutes,
            TaskTimeInterval.end(plannedDate: plannedDate, plannedTime: time, durationMinutes: duration) == nil
        {
            throw TaskTimeIntervalError.endOutOfRange
        }
        task.setPlannedDate(plannedDate)
        if plannedDate == nil {
            try task.setProductivity(task.subtasks, nil)
            task.setPlannedInterval(plannedTime: nil, durationMinutes: nil)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Assigns, changes or clears (nil/nil) the time interval of one task as a
    /// complete pair on top of its existing planned date. The whole candidate
    /// is validated before any property changes; one explicit save with
    /// rollback on failure. Completion, title, id and order are untouched.
    public func setPlannedInterval(
        plannedTime: String?,
        durationMinutes: Int?,
        for id: UUID
    ) throws {
        if !TaskTimeInterval.isCompletePair(time: plannedTime, durationMinutes: durationMinutes) {
            throw TaskTimeIntervalError.incompletePair(
                time: plannedTime,
                durationMinutes: durationMinutes
            )
        }
        if let plannedTime, !TaskTimeInterval.isValidTime(plannedTime) {
            throw TaskTimeIntervalError.invalidTime(plannedTime)
        }
        if let durationMinutes, !TaskTimeInterval.isValidDuration(durationMinutes) {
            throw TaskTimeIntervalError.invalidDuration(durationMinutes)
        }
        // NATIVE-MIN5 write minimum: a new or changed non-nil interval must
        // be whole minutes 5...1440. The precheck runs before any property
        // mutation or save; legacy stored 1...4 remain readable through the
        // read validator above and are never rewritten by this gate.
        if let durationMinutes, !TaskTimeInterval.isWritableDuration(durationMinutes) {
            throw TaskTimeIntervalError.invalidDuration(durationMinutes)
        }
        let descriptor = FetchDescriptor<OrbitTask>(predicate: #Predicate { $0.id == id })
        guard let task = try context.fetch(descriptor).first else {
            throw OrbitStoreError.taskNotFound(id: id)
        }
        if let plannedTime, let durationMinutes {
            guard let plannedDate = task.plannedDate else {
                throw TaskTimeIntervalError.missingDate
            }
            guard
                TaskTimeInterval.end(
                    plannedDate: plannedDate,
                    plannedTime: plannedTime,
                    durationMinutes: durationMinutes
                ) != nil
            else {
                throw TaskTimeIntervalError.endOutOfRange
            }
        }
        task.setPlannedInterval(plannedTime: plannedTime, durationMinutes: durationMinutes)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

public enum OrbitStoreError: Error, Equatable {
    case taskNotFound(id: UUID)
}
