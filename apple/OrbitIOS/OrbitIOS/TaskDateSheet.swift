import SwiftUI
import OrbitCore

/// Optional civil date draft with pinned native actions; opening and cancellation never write.
struct TaskDateSheet: View {
    let task: OrbitTask
    let model: IOSInboxModel

    @Environment(\.dismiss) private var dismiss
    @State private var hasDate: Bool
    @State private var draftDate: Date
    @State private var errorMessage: String?

    init(task: OrbitTask, model: IOSInboxModel) {
        self.task = task
        self.model = model
        let initial: Date
        if let saved = task.plannedDate {
            initial = TaskPlannedDate.date(fromCivilDateString: saved) ?? Date.now
        } else {
            initial = Date.now
        }
        _draftDate = State(initialValue: initial)
        _hasDate = State(initialValue: task.plannedDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Section("Дата") {
                    Toggle("Назначить дату", isOn: $hasDate)
                    DatePicker("Дата", selection: $draftDate, in: dateRange, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .labelsHidden().disabled(!hasDate)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                        .environment(\.calendar, Calendar.orbitCivil)
                }
                if let errorMessage {
                    Section {
                        OrbitErrorMessage(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.orbitError)
                            .accessibilityIdentifier("date-error")
                    }
                }
                if !hasDate {
                    Text("Без даты. Время и длительность тоже будут убраны после сохранения.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

            }
            .orbitEditorSurface()
            .navigationTitle("Дата задачи")
            .navigationBarTitleDisplayMode(.inline)
            .orbitEditorActions(save: save, cancel: { dismiss() })
        }
        .presentationDetents([.large])
        .orbitEditorSurface()
    }

    private var dateRange: ClosedRange<Date> {
        let lower = TaskPlannedDate.date(fromCivilDateString: "1900-01-01")!
        let upper = TaskPlannedDate.date(fromCivilDateString: "2199-12-31")!
        return lower...upper
    }

    private func save() {
        let value: String? = hasDate ? TaskPlannedDate.civilDateString(from: draftDate) : nil
        if let message = model.setPlannedDate(value, for: task) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

}
