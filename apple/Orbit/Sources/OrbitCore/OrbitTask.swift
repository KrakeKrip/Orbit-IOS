import Foundation
import SwiftData

@Model
public final class OrbitTask {
    public private(set) var id: UUID
    public private(set) var projectID: UUID?
    /// Independent end-of-day civil deadline; optional for additive upgrades.
    public private(set) var deadlineDate: String?
    /// One explicit absolute reminder instant, independent of civil scheduling.
    public private(set) var reminderAt: Date?
    public private(set) var title: String
    public private(set) var createdAt: Date
    public private(set) var completedAt: Date?
    /// Optional civil date `YYYY-MM-DD` (see `TaskPlannedDate`); nil when unset.
    /// Added as an optional field so existing stores and rows stay intact.
    public private(set) var plannedDate: String?
    /// Optional civil wall-clock start `HH:mm` of the interval
    /// (see `TaskTimeInterval`); always nil together with `durationMinutes`
    /// and only present on a dated task. Computed fields are not stored.
    public private(set) var plannedTime: String?
    /// Whole minutes 1...1440 of the interval; nil exactly when
    /// `plannedTime` is nil.
    public private(set) var durationMinutes: Int?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        plannedDate: String? = nil,
        plannedTime: String? = nil,
        durationMinutes: Int? = nil,
        projectID: UUID? = nil,
        deadlineDate: String? = nil,
        reminderAt: Date? = nil
    ) {
        self.reminderAt = reminderAt
        self.deadlineDate = deadlineDate
        self.projectID = projectID
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.plannedDate = plannedDate
        self.plannedTime = plannedTime
        self.durationMinutes = durationMinutes
    }

    func setReminderAt(_ value: Date?) { reminderAt = value }

    func setDeadlineDate(_ value: String?) { deadlineDate = value }

    func setProject(_ id: UUID?) { projectID = id }

    public var isCompleted: Bool {
        completedAt != nil
    }

    public func complete(at date: Date = .now) {
        guard !isCompleted else { return }
        completedAt = date
    }

    public func reopen() {
        guard isCompleted else { return }
        completedAt = nil
    }

    /// NATIVE-EDIT-001-R1: internal (module-only) title setter. It assigns
    /// the string as-is without validation — `OrbitTaskStore.renameTask` is
    /// the one validated entry point and the only caller, so no public raw
    /// bypass exists outside OrbitCore.
    func setTitle(_ value: String) {
        title = value
    }

    /// Assigns, changes or clears (`nil`) the planned civil date.
    /// Validation of the `YYYY-MM-DD` contract lives in `TaskPlannedDate`
    /// and in the store, which rejects invalid values before mutating.
    public func setPlannedDate(_ value: String?) {
        plannedDate = value
    }

    /// Assigns, changes or clears (nil/nil) the time interval as a whole pair.
    /// Pair/date/end validation lives in `TaskTimeInterval` and in the store,
    /// which rejects invalid candidates before mutating.
    public func setPlannedInterval(plannedTime: String?, durationMinutes: Int?) {
        self.plannedTime = plannedTime
        self.durationMinutes = durationMinutes
    }
}
