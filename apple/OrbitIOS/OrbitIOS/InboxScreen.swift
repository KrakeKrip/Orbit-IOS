import SwiftUI
import OrbitCore

/// Single accent of the screen: a restrained coral/red for the primary action
/// and completed state. Everything else stays system gray.
extension Color {
    static let orbitAccent = Color(red: 0.906, green: 0.345, blue: 0.286)
}

/// Which editor sheet is presented; identified by kind + task UUID so only
/// one date or interval editor exists at a time and each presentation
/// re-initializes its draft from persisted values.
enum InboxSheetPresentation: Identifiable {
    case date(OrbitTask)
    case interval(OrbitTask)

    var id: String {
        switch self {
        case .date(let task): "date-\(task.id.uuidString)"
        case .interval(let task): "interval-\(task.id.uuidString)"
        }
    }
}

/// The one iOS Inbox screen: large title, compact rows with round completion
/// circles and date/time actions. NATIVE-ADD-002: creation moved from the
/// removed bottom composer to the shared coral «+» with the one create sheet
/// (always undated here); a write error stays visible as a banner above the
/// content, next to the list or the empty state.
struct InboxScreen: View {
    @Environment(\.orbitAppearance) private var appearance
    @State private var model: IOSInboxModel
    @State private var presentation: InboxSheetPresentation?

    init(model: IOSInboxModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeModeHeader(switcher: EmptyView()) {
                    Text("Входящие").font(.title2.bold()).lineLimit(1)
                }
                if let writeError = model.writeError {
                    writeErrorBanner(writeError)
                }
                Group {
                    if model.listError != nil {
                        listErrorView
                    } else if model.tasks.isEmpty {
                        emptyView
                    } else {
                        taskList
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .background(appearance.canvas)
            .sheet(item: $presentation) { item in
                switch item {
                case .date(let task):
                    TaskDateSheet(task: task, model: model)
                case .interval(let task):
                    TaskIntervalSheet(task: task, model: model)
                }
            }
        }
        // NATIVE-ADD-002: the shared «+» replaces the removed bottom composer;
        // Inbox creation is always undated (nil preset).
        .orbitCreateAction(model: model, datePreset: { nil })
    }

    private var taskList: some View {
        List {
            if !model.openTasks.isEmpty {
                Section("Открытые") {
                    ForEach(model.openTasks) { task in
                        InboxRowView(task: task, model: model) {
                            presentation = .date(task)
                        } onEditInterval: {
                            presentation = .interval(task)
                        }
                        .listRowBackground(appearance.canvas)
                    }
                }
            }
            if !model.completedTasks.isEmpty {
                Section("Завершённые") {
                    ForEach(model.completedTasks) { task in
                        InboxRowView(task: task, model: model) {
                            presentation = .date(task)
                        } onEditInterval: {
                            presentation = .interval(task)
                        }
                        .listRowBackground(appearance.canvas)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("Пока нет задач", systemImage: "tray")
        } description: {
            Text("Нажмите «+», чтобы добавить первую задачу.")
        }
    }

    private var listErrorView: some View {
        ContentUnavailableView {
            Label("Не удалось загрузить задачи", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(model.listError ?? "")
        } actions: {
            Button("Повторить") { model.reload() }
                .buttonStyle(.borderedProminent)
                .tint(.orbitAccent)
        }
    }

    /// A failed complete/reopen or date/interval write on this screen: the
    /// shared model keeps `writeError` until the next successful mutation, so
    /// the reason stays visible above the content without masking the list,
    /// the empty state or a read failure. It is never shown inside the modal
    /// create sheet, which reports its own attempts in the form.
    private func writeErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .accessibilityIdentifier("inbox-write-error")
    }
}

/// One row: round completion control on the left and the tappable task body
/// (title + metadata). NATIVE-LIST-001: the always-visible clock/calendar
/// icons are gone — tapping the body opens a compact native menu with the
/// existing date and time/duration editors, while the circle stays an
/// independent complete/reopen control that never opens the menu. Titles
/// wrap instead of being truncated; hit areas are ≥ 44pt; rows are lower
/// through explicit compact vertical List insets.
struct InboxRowView: View {
    @Environment(\.orbitAppearance) private var appearance
    let task: OrbitTask
    let model: IOSInboxModel
    /// Row presentation flag (NATIVE-LIST-001): show the planned-date
    /// subtitle. Default true (Inbox keeps the useful date); Today and the
    /// day-grouped Upcoming sections pass false — their section headers
    /// already carry the date. Presentation only, no metadata loss.
    var showsDateLabel: Bool = true
    let onEditDate: () -> Void
    let onEditInterval: () -> Void

    /// NATIVE-EDIT-002: the one rename/delete presentation invoked from this
    /// row's menu, hosted on the stable row body — never on the ephemeral
    /// menu content. Only one management editor/confirmation is active at a
    /// time, and opening either writes nothing.
    @State private var renamePresentation: TaskRenamePresentation?
    @State private var deletePresentation: TaskDeletePresentation?

    private static let dateLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Kept for the existing interval editor caption; the row subtitle
    /// itself is formatted view-locally in Russian (see `body`).
    static func dateLabel(_ civilDate: String) -> String {
        guard let date = TaskPlannedDate.date(fromCivilDateString: civilDate) else {
            return civilDate
        }
        return dateLabelFormatter.string(from: date)
    }

    /// Derived "start–end" wall-clock range; a midnight crossing is marked
    /// with "(+1 день)". The end comes from `TaskTimeInterval.end` and is
    /// never stored.
    static func intervalLabel(_ task: OrbitTask) -> String? {
        guard let date = task.plannedDate,
            let time = task.plannedTime,
            let duration = task.durationMinutes,
            let end = TaskTimeInterval.end(plannedDate: date, plannedTime: time, durationMinutes: duration)
        else { return nil }
        if end.date == date {
            return "\(time)–\(end.time)"
        }
        return "\(time)–\(end.time) (+1 день)"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            CompletionButton(isCompleted: task.isCompleted) {
                model.setCompleted(!task.isCompleted, for: task)
            }
            .accessibilityLabel(
                task.isCompleted ? "Снова открыть: \(task.title)" : "Отметить выполненной: \(task.title)"
            )
            taskBodyMenu
        }
        // Keep natural multiline/metadata height and 44pt controls, while
        // replacing List's default top/bottom insets with a compact gap.
        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
        .listRowBackground(appearance.canvas)
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading] + 44 + 14
        }
        .taskManagementHost(
            model: model,
            renamePresentation: $renamePresentation,
            deletePresentation: $deletePresentation
        )
    }

    /// The tappable body: a compact native menu over the existing editor
    /// callbacks. Presentation only — opening/cancelling the menu never
    /// mutates anything, and the circle never triggers it.
    /// NATIVE-EDIT-002: the same shared menu gains «Переименовать…» and the
    /// destructive «Удалить…» (date/time items unchanged, the completion
    /// circle stays independent). Calendar cards use the same actions and
    /// shared UUIDs, so mutations are reflected across both presentations.
    private var taskBodyMenu: some View {
        TaskActionPopoverButton(
            model: model, task: task,
            range: Self.intervalLabel(task) ?? task.plannedDate.map(RussianDateCaption.label) ?? "Без даты",
            previewWidth: 300
        ) { action in
            switch action {
            case .toggle: model.setCompleted(!task.isCompleted, for: task)
            case .date: onEditDate()
            case .interval: onEditInterval()
            case .rename: renamePresentation = TaskRenamePresentation(task: task)
            case .delete: deletePresentation = TaskDeletePresentation(task: task)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                    .foregroundStyle(task.isCompleted ? Color.secondary : Color.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                TaskDeadlineBadge(task: task)
                TaskReminderBadge(task: task, service: model.reminders)
                if showsDateLabel, let plannedDate = task.plannedDate {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let today = TaskDaySelection.currentDay(from: context.date)
                        let missed = !task.isCompleted && TaskPlannedDate.isValid(plannedDate) && plannedDate < today
                        Text(RussianDateCaption.label(plannedDate))
                            .font(.footnote)
                            .foregroundStyle(missed ? Color.red : Color.secondary)
                            .accessibilityLabel(RussianDateCaption.label(plannedDate) + (missed ? ", запланированная дата прошла" : ""))
                    }
                }
                if let interval = Self.intervalLabel(task) {
                    Text(interval)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .orbitMenuFeedback()
        .accessibilityLabel(task.title + TaskDeadlineBadge.accessibilitySuffix(task) + TaskReminderBadge.accessibilitySuffix(task))
    }


}

/// Round Todoist-like completion control: calm gray outline, coral fill with a
/// white checkmark once completed; ≥ 44pt tappable.
struct CompletionButton: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.orbitAccent : Color.clear)
                Circle()
                    .strokeBorder(isCompleted ? Color.orbitAccent : Color(.systemGray3), lineWidth: 1.5)
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 26, height: 26)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isCompleted)
    }
}

/// Explicit open-failure state: explains the problem, never deletes the store,
/// never falls back to an empty in-memory database.
struct StoreFailureView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Хранилище недоступно", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(message)
        }
    }
}
