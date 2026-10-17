import Combine
import SwiftUI
import OrbitCore

/// One folder over the shared task objects; calendar and list never duplicate data.
struct ProjectWorkspaceScreen: View {
    let model: IOSInboxModel
    let project: OrbitProject
    let onBack: () -> Void
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.scenePhase) private var phase
    @AppStorage private var showsCalendar: Bool
    @State private var selectedDay = TaskDaySelection.currentDay()
    @State private var referenceDay = TaskDaySelection.currentDay()
    @State private var create = false
    @State private var editor: InboxSheetPresentation?
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    init(model: IOSInboxModel, project: OrbitProject, onBack: @escaping () -> Void) {
        self.model = model
        self.project = project
        self.onBack = onBack
        _showsCalendar = AppStorage(wrappedValue: false, "orbit.ui.project.\(project.id.uuidString).calendar")
    }

    private var tasks: [OrbitTask] { model.tasks.filter { $0.projectID == project.id } }

    private var header: some View {
        NativeModeHeader(switcher: OrbitViewModeMenu(showsCalendar: $showsCalendar, identifier: "project-mode-switcher")) {
            Button(action: onBack) {
                Image(systemName: "chevron.left").frame(minWidth: 32, minHeight: 44)
            }
            .accessibilityLabel("Все проекты")
            .accessibilityIdentifier("project-back")
            Text(project.name).font(.headline).lineLimit(1)
                .accessibilityIdentifier("project-title")
        }
    }

    var body: some View {
        Group {
            if showsCalendar {
                CalendarDayScreen(model: model, projectID: project.id,
                                  projectHeader: AnyView(header), todayMode: $showsCalendar,
                                  browsingDay: $selectedDay, referenceDay: referenceDay)
            } else {
                NavigationStack {
                    VStack(spacing: 0) {
                        header
                        if let error = model.listError {
                            ContentUnavailableView("Задачи недоступны", systemImage: "exclamationmark.triangle", description: Text(error))
                            Button("Повторить") { model.reload() }
                        } else if tasks.isEmpty {
                            ContentUnavailableView("В проекте пока нет задач", systemImage: "folder", description: Text("Добавьте первую задачу кнопкой «+»."))
                        } else {
                            List {
                                if let error = model.writeError { Text(error).foregroundStyle(.red) }
                                ForEach([false, true], id: \.self) { completed in
                                    let rows = tasks.filter { $0.isCompleted == completed }
                                    if !rows.isEmpty {
                                        Section(completed ? "Завершённые" : "Открытые") {
                                            ForEach(rows) { task in
                                                InboxRowView(task: task, model: model) { editor = .date(task) }
                                                    onEditInterval: { editor = .interval(task) }
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain).scrollContentBackground(.hidden)
                        }
                    }
                    .background(appearance.canvas)
                    .toolbar(.hidden, for: .navigationBar)
                    .sheet(item: $editor) { item in
                        switch item {
                        case .date(let task): TaskDateSheet(task: task, model: model)
                        case .interval(let task): TaskIntervalSheet(task: task, model: model)
                        }
                    }
                }
            }
        }
        .orbitFloatingAction(label: "Добавить задачу в проект", identifier: "project-add-task", enabled: !create) {
            OrbitHaptics.selection()
            create = true
        }
        .sheet(isPresented: $create) {
            TaskCreateSheet(model: model, datePreset: showsCalendar ? selectedDay : nil, projectPreset: project.id)
        }
        .onChange(of: showsCalendar) { _, _ in model.endSelection() }
        .onChange(of: selectedDay) { _, _ in model.endSelection() }
        .onDisappear { model.endSelection() }
        .onAppear { model.reload(); referenceDay = TaskDaySelection.currentDay() }
        .onReceive(timer) { _ in referenceDay = TaskDaySelection.currentDay() }
        .onChange(of: phase) { _, value in
            if value == .active { referenceDay = TaskDaySelection.currentDay() }
        }
    }
}

struct TaskProjectSheet: View {
    let model: IOSInboxModel
    let task: OrbitTask
    @Environment(\.dismiss) private var dismiss
    @State private var draft: UUID?
    @State private var error: String?

    init(model: IOSInboxModel, task: OrbitTask) {
        self.model = model; self.task = task
        _draft = State(initialValue: task.projectID)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(task.title) }
                Picker("Проект", selection: $draft) {
                    Text("Без проекта").tag(nil as UUID?)
                    ForEach(model.projects) { Text($0.name).tag(Optional($0.id)) }
                }
                .pickerStyle(.inline)
                .accessibilityIdentifier("task-project-picker")
                if let error { Text(error).foregroundStyle(.red) }
            }
            .orbitEditorSurface()
            .navigationTitle("Проект задачи")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        if let message = model.assignProject(draft, to: task) { error = message }
                        else { dismiss() }
                    }
                }
            }
        }
    }
}
