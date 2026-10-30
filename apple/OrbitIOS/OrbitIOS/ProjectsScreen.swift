import SwiftUI
import Combine
import OrbitCore

struct ProjectEditorPresentation: Identifiable {
    let id = UUID()
    var projectID: UUID?
    var name = ""
}

/// Project folders with live task context and shared name editor.
struct ProjectsScreen: View {
    let model: IOSInboxModel
    @Environment(\.orbitAppearance) private var appearance
    @AppStorage("orbit.ui.projects.expanded") private var projectsExpanded = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedProject: OrbitProject?
    @State private var editor: ProjectEditorPresentation?
    @Environment(\.scenePhase) private var phase
    @State private var today = TaskDaySelection.currentDay()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private var summaries: [UUID: ProjectTaskSummary] {
        ProjectTaskSummary.grouped(tasks: model.tasks, today: today)
    }

    var body: some View {
        Group {
            if let selectedProject {
                ProjectWorkspaceScreen(model: model, project: selectedProject) { self.selectedProject = nil }
            } else {
                projectIndex
            }
        }
    }

    private var projectIndex: some View {
        NavigationStack {
            OrbitTagsScreen(model: model, projectsContent: AnyView(projectRows))
                .refreshable { model.reload() }
                .orbitWorkspaceHeader(stabilizesListInsets: true) {
                    NativeModeHeader(title: "Проекты", switcher: EmptyView())
                }
                .orbitScrollingHeader()
            .sheet(item: $editor) { item in
                ProjectNameSheet(presentation: item, model: model)
            }

        }
        .orbitCreateAction(model: model, datePreset: { nil })
        .onAppear { model.reload(); today = TaskDaySelection.currentDay() }
        .onReceive(timer) { _ in today = TaskDaySelection.currentDay() }
        .onChange(of: phase) { _, value in if value == .active { model.reload(); today = TaskDaySelection.currentDay() } }
        .environment(\.orbitAllowsTaskSelection, false)
    }
    private var projectRows: some View {
        Section {
            if projectsExpanded {
                if let error = model.projectListError {
                    OrbitTaskLoadFailure(message: error, retry: { model.reloadProjects() })
                } else {
                    if let error = model.listError {
                        OrbitTaskLoadFailure(message: error, retry: { model.reload() })
                    }
                    if !model.projects.contains(where: { !$0.isArchived }) {
                        Text("Пока нет проектов")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                            .listRowSeparator(.hidden)
                            .listRowBackground(appearance.canvas)
                    }
                    ForEach(model.projects.filter { !$0.isArchived }) { project in
                        Button { selectedProject = project } label: {
                            ProjectIndexRow(name: project.name,
                                summary: summaries[project.id, default: ProjectTaskSummary()],
                                unavailable: model.listError != nil)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Открыть задачи проекта")
                        .accessibilityIdentifier("project-row-\(project.id.uuidString)")
                        .contextMenu {
                            Button("Переименовать…", systemImage: "pencil") {
                                editor = ProjectEditorPresentation(projectID: project.id, name: project.name)
                            }
                        }
                        .listRowBackground(appearance.canvas)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(project.id == model.projects.last(where: { !$0.isArchived })?.id ? .hidden : .visible, edges: .bottom)
                    }
                }
            }
        } header: {
            OrbitCollapsibleSectionHeader(title: "Мои проекты", expanded: $projectsExpanded,
                                          createLabel: "Создать проект", identifier: "project") {
                editor = ProjectEditorPresentation()
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: projectsExpanded)
    }

}

private struct ProjectIndexRow: View {
    let name: String
    let summary: ProjectTaskSummary
    let unavailable: Bool
    @Environment(\.orbitAppearance) private var appearance

    private var context: Text {
        if unavailable { return Text("Задачи недоступны") }
        if summary.total == 0 { return Text("Нет задач") }
        if summary.open == 0 { return Text("Всё выполнено") }
        if summary.today > 0 && summary.overdue > 0 {
            return Text("Сегодня: \(summary.today) · ") + Text("Просрочено: \(summary.overdue)").foregroundColor(.orbitError)
        }
        if summary.overdue > 0 { return Text("Просрочено: \(summary.overdue)").foregroundColor(.orbitError) }
        if summary.today > 0 { return Text("Сегодня: \(summary.today)") }
        if summary.undated > 0 { return Text("Без даты: \(summary.undated)") }
        return Text("Запланированы на другие дни")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "folder").font(.title3).foregroundStyle(Color.orbitAccent)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(name).font(.body.weight(.medium)).foregroundStyle(.primary)
                context.font(.footnote).foregroundStyle(appearance.secondaryText)
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            if !unavailable && summary.open > 0 {
                Text("\(summary.open)").font(.subheadline.monospacedDigit())
                    .foregroundStyle(appearance.secondaryText)
                    .padding(.horizontal, 8).frame(minWidth: 28, minHeight: 28)
                    .background(appearance.surface, in: Capsule())
                    .accessibilityLabel("Открытых задач: \(summary.open)")
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(appearance.secondaryText)
                .padding(.top, 6).accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .frame(minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ProjectNameSheet: View {
    let presentation: ProjectEditorPresentation
    let model: IOSInboxModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var error: String?
    @FocusState private var nameFocused: Bool

    init(presentation: ProjectEditorPresentation, model: IOSInboxModel) {
        self.presentation = presentation
        self.model = model
        _draft = State(initialValue: presentation.name)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Например, Работа", text: $draft, axis: .vertical).lineLimit(1...4)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .accessibilityLabel("Название проекта")
                        .accessibilityIdentifier("project-name")
                } header: {
                    Text("Название")
                } footer: {
                    Text("До \(ProjectName.maximumLength) символов.")
                }
                if let error {
                    Section {
                        OrbitErrorMessage(error)
                            .accessibilityIdentifier("project-editor-error")
                    }
                }
            }
            .orbitEditorSurface()
            .navigationTitle(presentation.projectID == nil ? "Новый проект" : "Проект")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draft.unicodeScalars.count > ProjectName.maximumLength)
                        .accessibilityIdentifier("project-save")
                }
            }
        }
        .task { nameFocused = true }
    }

    private func save() {
        if let message = model.saveProject(name: draft, for: presentation.projectID) {
            error = message
        } else {
            OrbitHaptics.selection()
            dismiss()
        }
    }
}
