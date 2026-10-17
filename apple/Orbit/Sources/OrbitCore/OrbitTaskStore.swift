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
        self.container = try ModelContainer(for: OrbitTask.self, OrbitProject.self, configurations: configuration)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        self.context = context
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
        reminderAt: Date? = nil
    ) throws -> OrbitTask {
        let title = try TaskTitle.validated(rawTitle)
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
            reminderAt: reminderAt
        )
        context.insert(task)
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
        return task
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
        if isCompleted {
            task.complete(at: date)
        } else {
            task.reopen()
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
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
