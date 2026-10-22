import SwiftUI
import OrbitCore

/// A deadline is an independent end-of-day limit, not a calendar appointment.
struct TaskDeadlineFields: View {
    @Binding var value: String?
    @Binding var expanded: Bool
    @State private var pickerDate: Date

    init(value: Binding<String?>, expanded: Binding<Bool>) {
        _value = value; _expanded = expanded
        _pickerDate = State(initialValue: value.wrappedValue.flatMap {
            TaskPlannedDate.date(fromCivilDateString: $0)
        } ?? Date.now)
    }

    var body: some View {
        VStack(spacing: 12) {
            Button { expanded.toggle() } label: {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        deadlineTitle.fixedSize()
                        Spacer(minLength: 8)
                        deadlineCaption.fixedSize()
                        disclosure
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            deadlineTitle
                            Spacer(minLength: 8)
                            disclosure
                        }
                        deadlineCaption
                    }
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("deadline-summary")
            if expanded {
                Toggle("Назначить срок", isOn: Binding(get: { value != nil }, set: { enabled in
                    value = enabled ? TaskPlannedDate.civilDateString(from: pickerDate) : nil
                }))
                DatePicker("Дедлайн", selection: $pickerDate,
                           in: TaskPlannedDate.date(fromCivilDateString: "1900-01-01")! ... TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!,
                           displayedComponents: .date)
                    .datePickerStyle(.wheel).labelsHidden().disabled(value == nil)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
                    .environment(\.calendar, Calendar.orbitCivil)
                    .accessibilityIdentifier("deadline-picker")
                    .onChange(of: pickerDate) { _, date in
                        if value != nil { value = TaskPlannedDate.civilDateString(from: date) }
                    }

            }
            Text("Срок до конца дня. Дата и время выполнения задаются отдельно.")
                .font(.footnote).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    private var deadlineTitle: some View {
        HStack(spacing: 8) { Image(systemName: "flag"); Text("Дедлайн") }
            .fixedSize(horizontal: true, vertical: true)
    }
    private var deadlineCaption: some View {
        Text(value.map(RussianDateCaption.label) ?? "Без срока")
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
    private var disclosure: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down").font(.footnote)
    }

}

struct TaskDeadlineSheet: View {
    let model: IOSInboxModel
    let task: OrbitTask
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String?
    @State private var expanded = true
    @State private var error: String?
    @State private var saved = false

    init(model: IOSInboxModel, task: OrbitTask) {
        self.model = model; self.task = task
        _draft = State(initialValue: task.deadlineDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") { Text(task.title) }
                Section { TaskDeadlineFields(value: $draft, expanded: $expanded) }
                if let error { Section { OrbitErrorMessage(error) } }
            }
            .orbitEditorSurface()
            .navigationTitle("Дедлайн")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.accessibilityIdentifier("deadline-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard !saved else { return }
                        if let message = model.setDeadlineDate(draft, for: task) { error = message }
                        else { saved = true; dismiss() }
                    }.accessibilityIdentifier("deadline-save")
                }
            }
        }
        .orbitEditorSurface()
    }
}

/// Minute refresh also updates overdue status across midnight without a store write.
struct TaskDeadlineBadge: View {
    @Environment(\.orbitAppearance) private var badgeAppearance

    let task: OrbitTask
    var compact = false
    var preview = false

    var body: some View {
        if let deadline = task.deadlineDate {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let today = TaskPlannedDate.civilDateString(from: context.date)
                let overdue = TaskDeadline.isOverdue(deadline, completed: task.isCompleted, today: today)
                Group {
                    if compact {
                        Image(systemName: overdue ? "flag.badge.ellipsis" : "flag.fill")
                    } else {
                        Label((overdue ? "Срок истёк · " : "Дедлайн · ") + RussianDateCaption.label(deadline),
                              systemImage: "flag")
                    }
                }
                .font(compact ? .caption : .footnote)
                .foregroundStyle(overdue ? Color.orbitError : badgeAppearance.secondaryText)
                .accessibilityLabel(Self.accessibilitySuffix(task, today: today))
                .accessibilityIdentifier("task-deadline-badge")
            }
        }
    }

    static func accessibilitySuffix(_ task: OrbitTask, today: String = TaskDaySelection.currentDay()) -> String {
        guard let date = task.deadlineDate else { return "" }
        let overdue = TaskDeadline.isOverdue(date, completed: task.isCompleted, today: today)
        return ", " + (overdue ? "Срок истёк, дедлайн " : "Дедлайн ") + RussianDateCaption.label(date)
    }
}
