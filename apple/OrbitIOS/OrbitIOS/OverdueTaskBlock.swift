import SwiftUI
import OrbitCore

/// One device-local missed-planning bucket shared by every task workspace.
struct OverdueTaskBlock: View {
    let model: IOSInboxModel
    var projectID: UUID? = nil
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            OverdueTaskContent(model: model, projectID: projectID,
                today: TaskDaySelection.currentDay(from: context.date))
        }
    }
}

struct TaskRescheduleRequest: Identifiable {
    let ids: [UUID]
    let id = UUID()
}

private struct OverdueTaskContent: View {
    let model: IOSInboxModel
    let projectID: UUID?
    let today: String
    @State private var expanded = false
    @State private var expandedHeight: CGFloat = 44
    @State private var request: TaskRescheduleRequest?
    @State private var editor: InboxSheetPresentation?
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.orbitAppearance) private var appearance
    private var tasks: [OrbitTask] {
        model.tasks.filter { (projectID == nil || $0.projectID == projectID)
            && TaskDaySelection.isOverdue($0, before: today) }
    }

    var body: some View {
        if !tasks.isEmpty, model.listError == nil {
            VStack(spacing: 0) {
                let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0)) : AnyLayout(HStackLayout())
                layout {
                    Button { expanded.toggle() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: expanded ? "chevron.down" : "chevron.right").font(.caption.bold())
                            Text("Просрочено · \(tasks.count)").font(.subheadline.weight(.semibold))
                        }.frame(minHeight: 44).fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.orbitError)
                    .accessibilityValue(expanded ? "Развёрнуто" : "Свёрнуто")
                    if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                    Menu("Перенести") {
                        moveActions(tasks.map(\.id))
                        Button("Выбрать задачи", systemImage: "checkmark.circle") {
                            model.beginSelection(); expanded = true
                        }
                    }
                    .font(.subheadline).frame(minHeight: 44)
                    .disabled(model.isSelecting)
                }
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                if let error { OrbitErrorMessage(error).padding(.horizontal, 16) }
                if expanded {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(tasks) { task in
                                HStack(spacing: 0) {
                                    InboxRowView(task: task, model: model) { editor = .date(task) }
                                        onEditInterval: { editor = .interval(task) }
                                    if !model.isSelecting {
                                        Menu { moveActions([task.id]) } label: {
                                            Image(systemName: "arrow.turn.up.right")
                                                .frame(width: 44, height: 44)
                                        }
                                        .accessibilityLabel("Перенести задачу: \(task.title)")
                                    }
                                }
                                .padding(.leading, 16)
                                Divider().padding(.leading, 74)
                            }
                        }
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { expandedHeight = $0 }
                    }
                    .frame(height: min(230, max(44, expandedHeight)))
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .buttonStyle(.plain)
            .background(appearance.canvas)
            .sheet(item: $request) { value in TaskRescheduleSheet(model: model, ids: value.ids) }
            .sheet(item: $editor) { value in
                switch value {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
        }
    }

    @ViewBuilder private func moveActions(_ ids: [UUID]) -> some View {
        Button("На сегодня", systemImage: "sun.max") {
            error = model.reschedule(ids, to: TaskDaySelection.currentDay())
        }
        Button("Выбрать дату…", systemImage: "calendar") {
            request = TaskRescheduleRequest(ids: ids)
        }
    }
}

struct TaskRescheduleSheet: View {
    let model: IOSInboxModel
    let ids: [UUID]
    var endsSelection = false
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date.now
    @State private var error: String?
    private var range: ClosedRange<Date> {
        TaskPlannedDate.date(fromCivilDateString: "1900-01-01")! ... TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Button("Отмена") { dismiss() }
                        Spacer()
                        Button("Перенести") {
                            error = model.reschedule(ids, to: TaskPlannedDate.civilDateString(from: date, calendar: .orbitCivil))
                            if error == nil { if endsSelection { model.endSelection() }; dismiss() }
                        }
                        .fontWeight(.semibold)
                        .disabled(ids.isEmpty)
                    }
                    .buttonStyle(.borderless)
                    .frame(minHeight: 44)
                }
                Section("Перенести задач: \(ids.count)") {
                    DatePicker("Новая дата", selection: $date, in: range, displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .environment(\.calendar, Calendar.orbitCivil)
                }
                Section { Text("Время и длительность сохранятся. Дедлайн и напоминание не изменятся.").font(.footnote).foregroundStyle(.secondary) }
                if let error { OrbitErrorMessage(error) }
            }
            .orbitEditorSurface()
            .navigationTitle("Перенос задач").navigationBarTitleDisplayMode(.inline)

        }
    }
}
