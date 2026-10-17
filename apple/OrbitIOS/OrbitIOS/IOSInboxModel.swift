import Foundation
import Observation
import OrbitCore

/// iOS-facing error texts in Russian; views never format store errors themselves.
enum IOSInboxFormatting {
    static func validationMessage(_ error: Error) -> String {
        switch error {
        case TaskTitleError.empty:
            return "Введите название задачи."
        case TaskTitleError.tooLong(let limit):
            return "Название не должно превышать \(limit) символов."
        default:
            return storageMessage(error)
        }
    }

    static func storageMessage(_ error: Error) -> String {
        switch error as? OrbitStoreError {
        case .taskNotFound:
            return "Задача не найдена в хранилище."
        case nil:
            break
        }
        return "Ошибка хранилища: \(error.localizedDescription)"
    }

    static func addMessage(_ error: Error) -> String {
        "Не удалось добавить задачу. \(validationMessage(error))"
    }

    /// NATIVE-ADD-004: user-facing message for a refused create candidate.
    /// The accepted formatters stay the source of the wording: date and
    /// interval errors use their specific texts (`plannedDateMessage`/
    /// `intervalMessage`), title errors the shared `addMessage`; anything
    /// else is an explicit store error, never silently generic.
    static func createMessage(_ error: Error) -> String {
        switch error {
        case is TaskTimeIntervalError:
            return "Не удалось добавить задачу. \(intervalMessage(error))"
        case is TaskPlannedDateError:
            return "Не удалось добавить задачу. \(plannedDateMessage(error))"
        case is TaskReminderError:
            return reminderMessage(error)
        case is TaskDeadlineError:
            return "Не удалось добавить задачу. Некорректный дедлайн (1900–2199)."
        case is TaskTitleError:
            return addMessage(error)
        default:
            return "Не удалось добавить задачу. \(storageMessage(error))"
        }
    }

    static func reminderMessage(_ error: Error) -> String {
        switch error {
        case TaskReminderError.past: return "Выберите будущее время напоминания."
        case TaskReminderError.invalidDate: return "Дата напоминания выходит за допустимый диапазон."
        case TaskReminderError.completedTask: return "Сначала снова откройте завершённую задачу."
        default: return "Не удалось сохранить напоминание. \(storageMessage(error))"
        }
    }

    static func completionMessage(_ error: Error) -> String {
        "Не удалось сохранить изменение. \(storageMessage(error))"
    }

    /// NATIVE-EDIT-002: the accepted title formatter stays the source of the
    /// wording for a refused rename (empty/too long), anything else is an
    /// explicit store error, never silently generic.
    static func renameMessage(_ error: Error) -> String {
        "Не удалось переименовать задачу. \(validationMessage(error))"
    }

    static func deletionMessage(_ error: Error) -> String {
        "Не удалось удалить задачу. \(storageMessage(error))"
    }

    static func plannedDateMessage(_ error: Error) -> String {
        switch error {
        case TaskPlannedDateError.invalid:
            return "Дата должна быть в формате ГГГГ-ММ-ДД (год 1900–2199)."
        case TaskTimeIntervalError.endOutOfRange:
            return "Не удалось сохранить дату: итоговое время задачи выходит за пределы 1900–2199."
        default:
            return "Не удалось сохранить дату. \(storageMessage(error))"
        }
    }

    static func intervalMessage(_ error: Error) -> String {
        switch error {
        case TaskTimeIntervalError.invalidTime(let value):
            return "Начало «\(value)» должно быть временем в формате ЧЧ:ММ (00:00–23:59)."
        case TaskTimeIntervalError.invalidDuration(let value):
            return "Длительность \(value) недопустима: укажите целое число минут от \(TaskTimeInterval.minimumWritableDurationMinutes) до \(TaskTimeInterval.maximumDurationMinutes)."
        case TaskTimeIntervalError.incompletePair:
            return "Укажите начало и длительность вместе."
        case TaskTimeIntervalError.missingDate:
            return "Сначала назначьте дату задачи."
        case TaskTimeIntervalError.endOutOfRange:
            return "Итоговое время задачи выходит за пределы календаря (1900–2199)."
        default:
            return "Не удалось сохранить время. \(storageMessage(error))"
        }
    }

    static func openMessage(_ error: Error) -> String {
        "Не удалось открыть хранилище. Данные не изменены. \(error.localizedDescription)"
    }
}

/// Main-actor state of the iOS Inbox. Every mutation goes through the shared
/// OrbitCore store's explicit save; failures keep the draft and roll the list
/// back to persisted truth.
@MainActor
@Observable
final class IOSInboxModel {
    private let store: OrbitTaskStore
    let reminders = OrbitReminderScheduler()

    private(set) var projects: [OrbitProject] = []
    private(set) var projectListError: String?
    private(set) var tasks: [OrbitTask] = []
    private(set) var listError: String?
    private(set) var writeError: String?

    init(store: OrbitTaskStore) {
        self.store = store
        reload()
    }

    var openTasks: [OrbitTask] {
        tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [OrbitTask] {
        tasks.filter { $0.isCompleted }
    }

    func reload() {
        reloadProjects()
        do {
            tasks = try store.tasks()
            listError = nil
            reminders.update(tasks)
        } catch {
            listError = IOSInboxFormatting.storageMessage(error)
        }
    }

    func setReminderAt(_ value: Date?, for task: OrbitTask) -> String? {
        do {
            try store.setReminderAt(value, for: task.id)
            writeError = nil
            reload()
            return nil
        } catch {
            reload()
            return IOSInboxFormatting.reminderMessage(error)
        }
    }

    func setDeadlineDate(_ value: String?, for task: OrbitTask) -> String? {
        do {
            try store.setDeadlineDate(value, for: task.id)
            writeError = nil
            reload()
            return nil
        } catch {
            reload()
            if error is TaskDeadlineError { return "Некорректный дедлайн (1900–2199)." }
            return "Не удалось сохранить дедлайн. \(IOSInboxFormatting.storageMessage(error))"
        }
    }

    func assignProject(_ projectID: UUID?, to task: OrbitTask) -> String? {
        do {
            try store.setProject(projectID, for: task.id)
            reload()
            return nil
        } catch {
            reload()
            return "Не удалось изменить проект. \(error.localizedDescription)"
        }
    }

    func reloadProjects() {
        do {
            projects = try store.projects()
            projectListError = nil
        } catch {
            projectListError = "Не удалось загрузить проекты. \(error.localizedDescription)"
        }
    }

    /// A successful save stays a success even if the subsequent list read fails.
    /// The same store/context is shared with tasks; no second container is opened.
    func saveProject(name: String, for id: UUID?) -> String? {
        do {
            if let id {
                try store.renameProject(name: name, for: id)
            } else {
                try store.addProject(name: name)
            }
            reloadProjects()
            return nil
        } catch {
            reloadProjects()
            switch error {
            case ProjectNameError.empty:
                return "Введите название проекта."
            case ProjectNameError.tooLong(let limit):
                return "Название не должно превышать \(limit) символов."
            case OrbitProjectStoreError.projectNotFound:
                return "Проект не найден. Закройте форму и обновите список."
            default:
                return "Не удалось сохранить проект. \(error.localizedDescription)"
            }
        }
    }

    /// NATIVE-ADD-002/ADD-004: creates one task with its whole optional
    /// candidate (civil date + optional time interval) through the accepted
    /// single-save `addTask` — never a create-then-edit sequence and no
    /// temporary OrbitTask/store insert for the draft. Returns nil on success
    /// (the list reloads from persisted truth; a subsequent read failure
    /// stays a list error and is not reported back as a write failure);
    /// otherwise returns a user-facing message for the create sheet, which
    /// stays open with all drafts for retry. The core validation is the
    /// final gate, not a UI-only save gate.
    @discardableResult
    func create(
        title: String,
        plannedDate: String?,
        plannedTime: String? = nil,
        durationMinutes: Int? = nil,
        projectID: UUID? = nil,
        deadlineDate: String? = nil,
        reminderAt: Date? = nil
    ) -> String? {
        do {
            _ = try store.addTask(
                title: title,
                plannedDate: plannedDate,
                plannedTime: plannedTime,
                durationMinutes: durationMinutes,
                projectID: projectID,
                deadlineDate: deadlineDate,
                reminderAt: reminderAt
            )
            writeError = nil
            reload()
            return nil
        } catch {
            reload()
            return IOSInboxFormatting.createMessage(error)
        }
    }

    /// NATIVE-EDIT-002: renames one task through the accepted validated
    /// `store.renameTask` (trim + title rules; UUID/date/time/completion are
    /// never touched and a normalized identical title is a store no-op — the
    /// internal model setter is never called from UI). Returns nil on success
    /// (the list reloads from persisted truth; a subsequent read failure
    /// stays a list error and is not reported back as a write failure);
    /// otherwise returns a user-facing message for the rename sheet, which
    /// keeps the draft for retry.
    func rename(title: String, for task: OrbitTask) -> String? {
        do {
            try store.renameTask(title: title, for: task.id)
            reload()
            return nil
        } catch {
            reload()
            return IOSInboxFormatting.renameMessage(error)
        }
    }

    /// NATIVE-EDIT-002: hard-deletes exactly one task; runs only from the
    /// confirmed destructive button (the confirmation with the visible full
    /// title lives in the shared management presentation). Follows the
    /// accepted completion pattern: a refused delete keeps the reason in the
    /// shared `writeError` — rendered on Inbox, Today and Upcoming alike, so
    /// it stays visible after the confirmation dialog has closed — and a
    /// retry always goes through a new explicit confirmation.
    func delete(_ task: OrbitTask) {
        do {
            try store.deleteTask(for: task.id)
            writeError = nil
            reload()
        } catch {
            writeError = IOSInboxFormatting.deletionMessage(error)
            reload()
        }
    }

    func setCompleted(_ isCompleted: Bool, for task: OrbitTask) {
        do {
            try store.setCompleted(isCompleted, for: task.id)
            writeError = nil
            reload()
        } catch {
            writeError = IOSInboxFormatting.completionMessage(error)
            reload()
        }
    }

    /// Assigns, changes or clears (`nil`) the planned date. Returns nil on
    /// success (the list is reloaded from persisted truth); otherwise returns
    /// a user-facing message for the date editor, which stays open for retry.
    func setPlannedDate(_ value: String?, for task: OrbitTask) -> String? {
        do {
            try store.setPlannedDate(value, for: task.id)
            reload()
            return nil
        } catch {
            reload()
            return IOSInboxFormatting.plannedDateMessage(error)
        }
    }

    /// Assigns, changes or clears (nil/nil) the time interval as a whole pair.
    /// Returns nil on success (the list is reloaded from persisted truth);
    /// otherwise returns a user-facing message for the interval editor, which
    /// stays open for retry. The pair is always passed to the store whole —
    /// the core remains the single source of validation rules.
    func setPlannedInterval(plannedTime: String?, durationMinutes: Int?, for task: OrbitTask) -> String? {
        do {
            try store.setPlannedInterval(plannedTime: plannedTime, durationMinutes: durationMinutes, for: task.id)
            reload()
            return nil
        } catch {
            reload()
            return IOSInboxFormatting.intervalMessage(error)
        }
    }
}
