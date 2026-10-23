import SwiftUI
import OrbitCore

struct ReminderPermissionView: View {
    @Environment(\.orbitAppearance) private var appearance
    let service: OrbitReminderScheduler
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(service.message).font(.footnote).foregroundStyle(appearance.secondaryText)
                .accessibilityIdentifier("reminder-permission-status")
            if service.status.authorization == .notDetermined {
                Button("Разрешить уведомления") { Task { await service.requestAuthorization() } }
                    .disabled(service.isRequesting).accessibilityIdentifier("reminder-permission-request")
            } else if service.status.authorization == .denied {
                Button("Настройки уведомлений") { service.openSettings() }
                    .accessibilityIdentifier("reminder-open-settings")
            }
            if service.status.authorization == .denied {
                Text("Не доставится: уведомления выключены").font(.footnote).foregroundStyle(Color.orbitError)
            } else if service.status.error != nil || service.authorizationError != nil {
                Button("Повторить проверку") {
                    if service.authorizationError != nil { Task { await service.requestAuthorization() } }
                    else { service.refresh() }
                }.frame(minHeight: 44).accessibilityIdentifier("reminder-retry")
            }
        }
    }
}

struct TaskReminderFields: View {
    @Environment(\.orbitAppearance) private var appearance
    @Binding var value: Date?
    @Binding var expanded: Bool
    let service: OrbitReminderScheduler
    let plannedDate: String?
    let plannedTime: String?
    @State private var pickerDate: Date

    init(value: Binding<Date?>, expanded: Binding<Bool>, service: OrbitReminderScheduler,
         plannedDate: String? = nil, plannedTime: String? = nil) {
        _value = value; _expanded = expanded; self.service = service
        self.plannedDate = plannedDate; self.plannedTime = plannedTime
        _pickerDate = State(initialValue: value.wrappedValue ?? TaskReminder.suggestedDate(
            plannedDate: plannedDate, plannedTime: plannedTime))
    }
    private var enabled: Binding<Bool> {
        Binding(get: { value != nil }, set: { flag in
            if flag {
                pickerDate = TaskReminder.suggestedDate(plannedDate: plannedDate, plannedTime: plannedTime)
                value = pickerDate
                expanded = true
                Task { await service.requestAuthorization() }
            } else { value = nil; expanded = false }
        })
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Напоминание", isOn: enabled)
                .accessibilityIdentifier("reminder-toggle")
            if let value {
                Button { expanded.toggle() } label: {
                    OrbitEditorSummary(title: "Когда", value: Self.caption(value), expanded: expanded)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("reminder-summary")
                if expanded {
                    DatePicker("Дата", selection: $pickerDate,
                               in: TaskPlannedDate.date(fromCivilDateString: "1900-01-01")! ... TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!,
                               displayedComponents: .date)
                        .datePickerStyle(.wheel).labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .environment(\.calendar, Calendar.orbitCivil)
                        .accessibilityIdentifier("reminder-date-picker")
                    DatePicker("Время", selection: $pickerDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel).labelsHidden()
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .environment(\.calendar, Calendar.orbitCivil)
                        .accessibilityIdentifier("reminder-time-picker")
                }
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    if value <= context.date {
                        Text("Время уже прошло. Выберите будущее время, чтобы получить напоминание.")
                            .font(.footnote).foregroundStyle(Color.orbitError)
                            .accessibilityIdentifier("reminder-past-hint")
                    }
                }
                Text("Время показано для текущего часового пояса. Перенос задачи не меняет напоминание.")
                    .font(.footnote).foregroundStyle(appearance.secondaryText)
                ReminderPermissionView(service: service)
            }
        }
        .onChange(of: pickerDate) { _, date in
            if value != nil { value = Date(timeIntervalSince1970: floor(date.timeIntervalSince1970 / 60) * 60) }
        }
    }
    static func caption(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar.orbitCivil
        formatter.timeZone = .current
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        return formatter.string(from: value)
    }
}

struct TaskReminderSheet: View {
    let model: IOSInboxModel
    let task: OrbitTask
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date?
    @State private var expanded = true
    @State private var error: String?
    @State private var saved = false
    init(model: IOSInboxModel, task: OrbitTask) {
        self.model = model; self.task = task
        _draft = State(initialValue: task.reminderAt)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") { Text(task.title) }
                Section {
                    if task.isCompleted {
                        Text("Задача завершена. Напоминание отменено. Снова откройте задачу, чтобы назначить новое.")
                        if draft != nil { Button("Без напоминания") { draft = nil } }
                    } else {
                        TaskReminderFields(value: $draft, expanded: $expanded, service: model.reminders,
                                           plannedDate: task.plannedDate, plannedTime: task.plannedTime)
                    }
                }
                if let error { Section { OrbitErrorMessage(error) } }
            }
            .orbitEditorSurface().navigationTitle("Напоминание").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }.accessibilityIdentifier("reminder-cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        guard !saved else { return }
                        if let message = model.setReminderAt(draft, for: task) { error = message }
                        else { saved = true; dismiss() }
                    }.accessibilityIdentifier("reminder-save")
                }
            }
        }.orbitEditorSurface()
    }
}

struct TaskReminderBadge: View {
    @Environment(\.orbitAppearance) private var badgeAppearance

    let task: OrbitTask
    let service: OrbitReminderScheduler
    var compact = false
    var preview = false
    var body: some View {
        if let date = task.reminderAt, !task.isCompleted {
            Group {
                if compact { Image(systemName: service.status.authorization == .denied ? "bell.slash.fill" : "bell.fill") }
                else {
                    let suffix = service.status.authorization == .denied ? " · уведомления выключены" :
                        service.status.error != nil ? " · проверьте уведомления" :
                        service.status.deferredCount > 0 && date > .now && !service.status.scheduledIDs.contains(ReminderRequest.prefix + task.id.uuidString) ? " · в очереди" : ""
                    Label(TaskReminderFields.caption(date) + suffix, systemImage: "bell")
                }
            }
            .font(compact ? .caption : .footnote)
            .foregroundStyle(service.status.authorization == .denied || service.status.error != nil ? Color.orbitError : badgeAppearance.secondaryText)
            .accessibilityIdentifier("task-reminder-badge")
        }
    }
    static func accessibilitySuffix(_ task: OrbitTask) -> String {
        guard let date = task.reminderAt, !task.isCompleted else { return "" }
        return ", Напоминание " + TaskReminderFields.caption(date)
    }
}
