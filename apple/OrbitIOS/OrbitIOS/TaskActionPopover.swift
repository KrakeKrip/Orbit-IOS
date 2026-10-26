import SwiftUI
import OrbitCore

enum OrbitTaskAction {
    case toggle, date, interval, rename, delete
}

/// Shared tap entry to a full task draft. The legacy geometry arguments are
/// retained at calendar call sites; presentation no longer depends on them.
struct TaskActionPopoverButton<Content: View>: View {
    let model: IOSInboxModel
    let task: OrbitTask
    let range: String
    let previewWidth: CGFloat
    var maximumHeight: CGFloat = 520
    var anchorsAtTap = false
    var calendarViewport: CGRect? = nil
    var opensOnHold = true
    var canOpen: () -> Bool = { true }
    let onAction: (OrbitTaskAction) -> Void
    @ViewBuilder let label: () -> Content
    @State private var showsTaskEditor = false

    var body: some View {
        Button {
            if model.isSelecting { model.toggleSelection(task); return }
            if canOpen() { showsTaskEditor = true }
        } label: { label() }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            if model.isSelecting { model.toggleSelection(task) }
            else if canOpen() { showsTaskEditor = true }
        }
        .modifier(TaskQuickMenuModifier(enabled: opensOnHold && !model.isSelecting,
                                        model: model, task: task, action: onAction))
        .sheet(isPresented: $showsTaskEditor) {
            TaskCreateSheet(model: model, datePreset: nil, editingTask: task)
        }
    }
}

/// Calendar holds remain dedicated to moving/resizing; lists use native menus.
private struct TaskQuickMenuModifier: ViewModifier {
    @Environment(\.orbitTaskSelectionScope) private var selectionScope
    let enabled: Bool
    let model: IOSInboxModel
    let task: OrbitTask
    let action: (OrbitTaskAction) -> Void
    func body(content: Content) -> some View {
        if enabled {
            content.contextMenu {
                Button(task.isCompleted ? "Снова открыть" : "Завершить", systemImage: "checkmark.circle") { action(.toggle) }
                Button("Выбрать", systemImage: "checkmark.circle.badge.plus") {
                    model.beginSelection(scope: selectionScope)
                    model.toggleSelection(task)
                }
                Button("Удалить…", systemImage: "trash", role: .destructive) { action(.delete) }
            }
        } else { content }
    }
}
