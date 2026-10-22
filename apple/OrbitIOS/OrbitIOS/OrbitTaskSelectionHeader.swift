import OrbitCore
import SwiftUI

struct OrbitTaskSelectionHeader: View {
    let model: IOSInboxModel
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack { cancel; Spacer(minLength: 8); countLabel }
            VStack(alignment: .leading, spacing: 4) { countLabel; cancel }
        }

    }
    private var cancel: some View { Button("Отмена") { model.endSelection() }.frame(minHeight: 44) }
    private var countLabel: some View {
        Text("Выбрано: \(model.selectedTaskIDs.count)").font(.headline)
            .accessibilityIdentifier("task-selection-count")
    }

}

/// Root-level host remains stable while selected rows are changed or deleted.
struct OrbitTaskSelectionActions: View {
    let model: IOSInboxModel
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmingDelete = false
    @State private var moveRequest: TaskRescheduleRequest?
    @State private var moveError: String?
    private var count: Int { model.selectedTaskIDs.count }

    var body: some View {
        VStack(spacing: 8) {
            if let error = moveError ?? model.selectionError {
                OrbitErrorMessage(error)
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 10))
            layout {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Удалить", systemImage: "trash").font(.subheadline).foregroundStyle(Color.orbitError)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel("Удалить")
                .accessibilityIdentifier("task-selection-delete")
                Menu {
                    Button("На сегодня", systemImage: "sun.max") {
                        moveError = model.reschedule(Array(model.selectedTaskIDs), to: TaskDaySelection.currentDay())
                        if moveError == nil { model.endSelection() }
                    }
                    Button("Выбрать дату…", systemImage: "calendar") {
                        moveRequest = TaskRescheduleRequest(ids: Array(model.selectedTaskIDs))
                    }
                } label: {
                    Label("Перенести", systemImage: "calendar.badge.clock").font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.orbitAccent.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel("Перенести выбранные задачи")
                Button { model.completeSelection() } label: {
                    Label("Завершить", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(Color.orbitAccentFill, in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityIdentifier("task-selection-complete")
            }
            .labelStyle(SelectionActionLabelStyle())
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.45 : 1)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.primary.opacity(0.08), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.10), radius: 16, y: 5)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .sheet(item: $moveRequest) { value in
            TaskRescheduleSheet(model: model, ids: value.ids, endsSelection: true)
        }
        .alert("Удалить выбранные задачи?", isPresented: $confirmingDelete) {
            Button("Удалить задачи (\(count))", role: .destructive) { model.deleteSelection() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выбрано: \(count). Это действие нельзя отменить.")
        }
    }
}

private struct SelectionActionLabelStyle: LabelStyle {
    @Environment(\.dynamicTypeSize) private var typeSize
    func makeBody(configuration: Configuration) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(HStackLayout(spacing: 8)) : AnyLayout(VStackLayout(spacing: 4))
        layout { configuration.icon; configuration.title.multilineTextAlignment(.center) }
            .padding(.vertical, 8).padding(.horizontal, 4)
    }
}
