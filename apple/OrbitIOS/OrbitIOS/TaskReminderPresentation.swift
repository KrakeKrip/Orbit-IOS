import SwiftUI
import OrbitCore

struct ReminderPermissionView: View {
    let service: OrbitReminderScheduler
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(service.message).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("reminder-permission-status")
            if service.status.authorization == .notDetermined {
                Button("Разрешить уведомления") { Task { await service.requestAuthorization() } }
                    .disabled(service.isRequesting).accessibilityIdentifier("reminder-permission-request")
            } else if service.status.authorization == .denied {
                Button("Настройки уведомлений") { service.openSettings() }
                    .accessibilityIdentifier("reminder-open-settings")
            }
            if service.status.error != nil || service.authorizationError != nil {
                Button("Повторить проверку") { Task { await service.requestAuthorization() } }
                    .accessibilityIdentifier("reminder-retry")
            }
        }
    }
}

struct TaskReminderFields: View {
    @Binding var value: Date?
    @Binding var expanded: Bool
    let service: OrbitReminderScheduler
    @State private var pickerDate: Date

    init(value: Binding<Date?>, expanded: Binding<Bool>, service: OrbitReminderScheduler) {
        _value = value; _expanded = expanded; self.service = service
        _pickerDate = State(initialValue: value.wrappedValue ?? Self.defaultDate())
    }
    private static func defaultDate() -> Date {
        Date(timeIntervalSince1970: ceil((Date.now.timeIntervalSince1970 + 3600) / 60) * 60)
    }
    private var enabled: Binding<Bool> {
        Binding(get: { value != nil }, set: { flag in
            if flag {
                if pickerDate <= .now { pickerDate = Self.defaultDate() }
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
                    HStack {
                        Text(Self.caption(value)).multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityIdentifier("reminder-summary")
                if expanded {
                    DatePicker("Дата", selection: $pickerDate,
                               in: TaskPlannedDate.date(fromCivilDateString: "1900-01-01")! ... TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!,
                               displayedComponents: .date)
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
                            .font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("reminder-past-hint")
                    }
                }
                Text("Время показано для текущего часового пояса. Перенос задачи не меняет напоминание.")
                    .font(.footnote).foregroundStyle(.secondary)
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
                        if draft != nil { Button("Убрать напоминание", role: .destructive) { draft = nil } }
                    } else {
                        TaskReminderFields(value: $draft, expanded: $expanded, service: model.reminders)
                    }
                }
                if let error { Section { Text(error).foregroundStyle(.red) } }
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
            .font(.caption)
            .foregroundStyle(preview ? Color.white : service.status.authorization == .denied || service.status.error != nil ? Color.orange : Color.secondary)
            .accessibilityIdentifier("task-reminder-badge")
        }
    }
    static func accessibilitySuffix(_ task: OrbitTask) -> String {
        guard let date = task.reminderAt, !task.isCompleted else { return "" }
        return ", Напоминание " + TaskReminderFields.caption(date)
    }
}
