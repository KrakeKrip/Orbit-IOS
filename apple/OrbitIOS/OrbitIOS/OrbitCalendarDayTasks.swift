import SwiftUI
import OrbitCore

/// Full-size reading surface for the same projected day, including overnight
/// continuations. It does not change the calendar mode or the selected date.
struct OrbitCalendarDayTasks: View {
    let model: IOSInboxModel
    let day: String
    var projectID: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var editor: InboxSheetPresentation?
    private var tasks: [OrbitTask] {
        let source = model.tasks.filter { projectID == nil || $0.projectID == projectID }
        let projection = TaskDayProjector.project(day: day, in: source)
        let lookup = Dictionary(uniqueKeysWithValues: source.map { ($0.id, $0) })
        var seen = Set<UUID>()
        return (projection.untimedTaskIDs + projection.timedSegments.map(\.taskID))
            .filter { seen.insert($0).inserted }.compactMap { lookup[$0] }
    }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if tasks.isEmpty {
                        Text("На этот день задач нет")
                    } else {
                        ForEach(tasks) { task in
                            InboxRowView(task: task, model: model, showsDateLabel: false, showsProjectLabel: projectID == nil) {
                                editor = .date(task)
                            } onEditInterval: {
                                editor = .interval(task)
                            }
                        }
                    }
                } header: { Text(RussianDateCaption.label(day)).font(.caption) }
            }
            .orbitEditorSurface()
            .navigationTitle("Задачи дня")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Готово") { dismiss() } }
            }
            .sheet(item: $editor) { item in
                switch item {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
        }
    }
}
