import SwiftUI
import OrbitCore

/// A fresh search session for every presentation: no hidden persisted filters.
struct TaskSearchScreen: View {
    let model: IOSInboxModel
    let projectID: UUID?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.orbitAppearance) private var appearance
    @State private var query = TaskSearch()
    @State private var thisProject = true
    @State private var editor: TaskRenamePresentation?

    private var results: [OrbitTask] {
        var value = query
        value.projectID = thisProject ? projectID : nil
        return value.results(in: model.tasks)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if projectID != nil {
                    Picker("Область поиска", selection: $thisProject) {
                        Text("Этот проект").tag(true)
                        Text("Все задачи").tag(false)
                    }.pickerStyle(.segmented).padding(.horizontal)
                }
                HStack {
                    Menu {
                        Picker("Статус", selection: $query.status) {
                            Text("Все").tag(TaskSearch.Status.all)
                            Text("Открытые").tag(TaskSearch.Status.open)
                            Text("Завершённые").tag(TaskSearch.Status.completed)
                        }
                        Picker("Тег", selection: $query.tagID) {
                            Text("Все теги").tag(Optional<UUID>.none)
                            ForEach(model.tags) { Text($0.name).tag(Optional($0.id)) }
                        }
                        Toggle("Без даты", isOn: $query.undatedOnly)
                        Toggle("Без проекта", isOn: $query.unassignedOnly)
                            .disabled(projectID != nil && thisProject)
                    } label: { Label("Фильтры", systemImage: "line.3.horizontal.decrease") }
                    Spacer()
                    if query.tagID != nil || query.status != .all || query.undatedOnly || query.unassignedOnly {
                        Button("Сбросить") {
                            query.tagID = nil; query.status = .all; query.undatedOnly = false; query.unassignedOnly = false
                        }
                    }
                }.padding(.horizontal).padding(.vertical, 8)
                Text(filterSummary).font(.footnote).foregroundStyle(appearance.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                if let error = model.listError {
                    OrbitTaskLoadFailure(message: error, retry: { model.reload() })
                } else if results.isEmpty {
                    ContentUnavailableView("Ничего не найдено", systemImage: "magnifyingglass",
                                           description: Text("Измените запрос или сбросьте фильтры."))
                } else {
                    List {
                        Section("Найдено: \(results.count)") {
                            ForEach(results) { task in
                                Button { editor = TaskRenamePresentation(task: task) } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(task.title).foregroundStyle(.primary)
                                        Text(context(for: task)).font(.footnote).foregroundStyle(appearance.secondaryText)
                                    }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain).listRowBackground(appearance.canvas)
                            }
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
            }
            .background(appearance.canvas)
            .navigationTitle("Поиск задач").navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query.text, placement: .navigationBarDrawer(displayMode: .always), prompt: "Название задачи")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } } }
            .sheet(item: $editor) { item in TaskCreateSheet(model: model, datePreset: nil, editingTask: item.task) }
        }
        .onChange(of: thisProject) { _, value in if value { query.unassignedOnly = false } }
    }

    private var filterSummary: String {
        var parts = [query.status == .all ? "Все статусы" : query.status == .open ? "Открытые" : "Завершённые"]
        if let id = query.tagID { parts.append("#" + (model.tags.first { $0.id == id }?.name ?? "Тег")) }
        if query.undatedOnly { parts.append("Без даты") }
        if query.unassignedOnly { parts.append("Без проекта") }
        return parts.joined(separator: " · ")
    }
    private static let dateFormatter: DateFormatter = {
        let value = DateFormatter()
        value.locale = Locale(identifier: "ru_RU")
        value.calendar = Calendar(identifier: .gregorian)
        value.dateStyle = .medium
        return value
    }()
    private func context(for task: OrbitTask) -> String {
        let project = model.projects.first { $0.id == task.projectID }?.name ?? "Без проекта"
        let date = task.plannedDate.flatMap { TaskPlannedDate.date(fromCivilDateString: $0) }
            .map { Self.dateFormatter.string(from: $0) } ?? "Без даты"
        let tags = model.tags.filter { (task.tagIDs ?? []).contains($0.id) }.map { "#" + $0.name }.joined(separator: " ")
        return ([project, date, task.isCompleted ? "Завершена" : "Открыта"] + (tags.isEmpty ? [] : [tags])).joined(separator: " · ")
    }
}
