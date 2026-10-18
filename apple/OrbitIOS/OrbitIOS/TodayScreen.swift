import SwiftUI
import OrbitCore

/// The «Сегодня» list: tasks planned on the device's current local civil
/// date. Read-only slice over the shared model — the same rows, editors and
/// sheets as the Inbox; NATIVE-ADD-002: creation happens through the shared
/// «+» hosted by `TodayWorkspaceScreen` with the current day preset, so this
/// screen has no add action of its own.
/// NATIVE-NAV-001: the current day is owned by `TodayWorkspaceScreen` and
/// provided as the `day` input. NATIVE-UI-MODE/R1: there is no navigation
/// title or bar on this screen — the compact «Список / Календарь» switcher
/// sits in the one common top mode row (`NativeModeHeader`) directly under
/// the safe area, the same host as the calendar presentation, so the control
/// keeps its physical position when the view switches (user clarification:
/// the former «Сегодня» title area is freed; the section's local date
/// caption below stays, the bottom tab name is unchanged). Task dates are
/// never rewritten.
struct TodayScreen: View {
    @Environment(\.orbitAppearance) private var appearance
    let model: IOSInboxModel
    let day: String
    var todayMode: Binding<Bool>? = nil

    @State private var presentation: InboxSheetPresentation?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let todayMode {
                    NativeModeHeader(switcher: TodayModeSwitcher(showsCalendar: todayMode))
                }
                OverdueTaskBlock(model: model)
                if let writeError = model.writeError {
                    writeErrorBanner(writeError)
                }
                Group {
                    if model.listError != nil {
                        listErrorView
                    } else if model.tasks.isEmpty || todayTasks.isEmpty {
                        emptyView
                    } else {
                        taskList
                    }
                }
            }
            // NATIVE-UI-MODE/R1: no navigation title/bar in any section view —
            // the common mode row is the deterministic top row directly under
            // the safe area in the list and calendar alike, so the switcher
            // never moves (the former «Сегодня» title area is freed).
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
    }

    private var todayTasks: [OrbitTask] {
        TaskDaySelection.tasks(onDay: day, in: model.tasks)
    }

    private var openTasks: [OrbitTask] {
        todayTasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [OrbitTask] {
        todayTasks.filter { $0.isCompleted }
    }

    private var taskList: some View {
        List {
            Section {
                Text(dateCaption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.canvas)
            }
            if !openTasks.isEmpty {
                Section("Открытые") {
                    ForEach(openTasks) { task in
                        // NATIVE-LIST-001: the section header already shows
                        // the day — no repeated date subtitle in the row.
                        InboxRowView(task: task, model: model, showsDateLabel: false) {
                            presentation = .date(task)
                        } onEditInterval: {
                            presentation = .interval(task)
                        }
                    }
                }
            }
            if !completedTasks.isEmpty {
                Section("Завершённые") {
                    ForEach(completedTasks) { task in
                        InboxRowView(task: task, model: model, showsDateLabel: false) {
                            presentation = .date(task)
                        } onEditInterval: {
                            presentation = .interval(task)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
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

    /// A failed complete/reopen (or another write) on this screen: the shared
    /// model keeps `writeError` until the next successful mutation, so the
    /// reason stays visible next to the content without masking the list,
    /// empty state or a read failure. The view never clears it.
    private func writeErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .accessibilityIdentifier("today-write-error")
    }

    /// NATIVE-ADD-002: the calm empty day — no tasks to do today. The local
    /// day stays visible, and adding happens through the shared «+» with the
    /// today preset, so there is no tab-switching action here. A day with
    /// only completed tasks never reaches this state: the list keeps showing
    /// its «Завершённые» history.
    private var emptyView: some View {
        VStack(spacing: 0) {
            // Local day stays visible even on a completely empty store.
            Text(dateCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            ContentUnavailableView {
                Label(model.tasks.contains { TaskDaySelection.isOverdue($0, before: day) } ? "На сегодня задач нет" : "На сегодня всё", systemImage: "sun.max")
            } description: {
                Text(model.tasks.contains { TaskDaySelection.isOverdue($0, before: day) } ? "Просроченные дела — в блоке выше." : "Можно отдохнуть — или добавить новые планы.")
            }
            Spacer(minLength: 0)
        }
    }

    /// NATIVE-NAV-002: the section-level date caption is formatted view-
    /// locally in Russian (explicit ru_RU/Gregorian adapters), not through
    /// the system-locale shared row label.
    private var dateCaption: String {
        RussianDateCaption.label(day)
    }
}
