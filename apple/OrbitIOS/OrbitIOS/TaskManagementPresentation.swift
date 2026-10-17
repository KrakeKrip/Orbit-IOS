import SwiftUI
import OrbitCore

/// NATIVE-EDIT-002: rename/delete presentations shared by every list that
/// renders `InboxRowView` (Inbox, Today, Upcoming). A fresh UUID per opening
/// gives every presentation a new identity (the accepted create-sheet
/// pattern), so the rename draft is always re-seeded from the persisted title
/// and a cancelled draft can never resurrect on reopen.
struct TaskRenamePresentation: Identifiable {
    let id = UUID()
    /// The row task at opening time; only its UUID and persisted title are
    /// read — the store stays the source of truth for the write.
    let task: OrbitTask
}

struct TaskDeletePresentation: Identifiable {
    let id = UUID()
    let task: OrbitTask
}

/// Hosts the rename sheet and the delete confirmation on the stable row body
/// — never inside the ephemeral menu content — so the existing date/interval
/// sheets keep their per-screen hosts and the row geometry stays untouched.
/// Opening or cancelling either presentation writes and deletes nothing.
struct TaskManagementHostModifier: ViewModifier {
    let model: IOSInboxModel
    @Binding var renamePresentation: TaskRenamePresentation?
    @Binding var deletePresentation: TaskDeletePresentation?

    func body(content: Content) -> some View {
        content
            .sheet(item: $renamePresentation) { item in
                TaskRenameSheet(model: model, task: item.task)
            }
            .confirmationDialog(
                "Удалить задачу?",
                isPresented: Binding(
                    get: { deletePresentation != nil },
                    set: { if !$0 { deletePresentation = nil } }
                ),
                titleVisibility: .visible,
                presenting: deletePresentation
            ) { item in
                // One destructive action per confirmation: the presentation is
                // cleared first, so a retry always goes through the menu and a
                // new explicit confirmation. A refused delete keeps the shared
                // error visible after the dialog has closed.
                Button("Удалить", role: .destructive) {
                    deletePresentation = nil
                    model.delete(item.task)
                }
                Button("Отмена", role: .cancel) { }
            } message: { item in
                // The full title stays visible and wraps on long names; the
                // wording states honestly that this hard delete has no undo.
                Text("«\(item.task.title)» будет удалена безвозвратно — восстановить задачу нельзя.")
            }
    }
}

extension View {
    /// Attach once per row body (a stable view in the list), never inside the
    /// `Menu` label: menu content is ephemeral and cannot host presentations.
    func taskManagementHost(
        model: IOSInboxModel,
        renamePresentation: Binding<TaskRenamePresentation?>,
        deletePresentation: Binding<TaskDeletePresentation?>
    ) -> some View {
        modifier(
            TaskManagementHostModifier(
                model: model,
                renamePresentation: renamePresentation,
                deletePresentation: deletePresentation
            )
        )
    }
}

/// NATIVE-EDIT-002: the one rename editor shared by Inbox/Today/Upcoming
/// through `InboxRowView`. The draft is local to this opening and seeded from
/// the actual persisted title; «Сохранить» and keyboard submit send the field
/// text through `model.rename`, whose accepted `store.renameTask` trims and
/// validates (the internal model setter is never called from UI). A refused
/// save keeps the sheet open with the draft and a visible message for retry;
/// success closes the sheet — the shared model has already reloaded from
/// persisted truth. «Отмена»/swipe dismiss without any write, and a `saved`
/// flag makes a repeated submit after success a no-op.
struct TaskRenameSheet: View {
    let model: IOSInboxModel
    let task: OrbitTask

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFieldFocused: Bool
    @State private var title: String
    @State private var errorMessage: String?
    /// Set only on confirmed success; a repeated submit in the same turn
    /// (double tap) can then never rename twice.
    @State private var saved = false

    init(model: IOSInboxModel, task: OrbitTask) {
        self.model = model
        self.task = task
        // Every opening starts from the actual persisted title, never from a
        // previous (possibly cancelled) draft.
        _title = State(initialValue: task.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Название задачи", text: $title, prompt: Text("Название задачи"))
                        .focused($titleFieldFocused)
                        .submitLabel(.done)
                        .onSubmit(save)

                        .accessibilityIdentifier("rename-title-field")
                }
                Section {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("rename-error")
                    }
                    Button(action: save) {
                        Text("Сохранить")
                            .frame(maxWidth: .infinity)
                    }
                    .orbitPrimaryStyle()
                    .accessibilityIdentifier("rename-save-button")

                    Button("Отмена") { dismiss() }
                        .orbitSecondaryStyle()
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("rename-cancel-button")
                }
            }
            .orbitEditorSurface()
            .navigationTitle("Переименовать")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { titleFieldFocused = true }
        }
        .presentationDetents([.medium, .large])
        .orbitEditorSurface()
    }

    private func save() {
        guard !saved else { return }
        // The raw field text goes to the accepted store validation (trim +
        // 1...500); the core stays the final gate.
        if let message = model.rename(title: title, for: task) {
            errorMessage = message
        } else {
            saved = true
            dismiss()
        }
    }
}

/// Shared menu vocabulary; each surface supplies callbacks to its stable host.
struct OrbitTaskMenuActions: View {
    let task: OrbitTask
    let onToggle: () -> Void
    let onEditDate: () -> Void
    let onEditInterval: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    var onEditProject: (() -> Void)? = nil
    var onEditDeadline: (() -> Void)? = nil
    var onEditReminder: (() -> Void)? = nil
    var body: some View {
        Button(action: onToggle) {
            Label(task.isCompleted ? "Снова открыть" : "Завершить",
                  systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
        }
        Button(action: onEditDate) { Label("Дата…", systemImage: "calendar") }
        Button(action: onEditInterval) { Label("Время и длительность…", systemImage: "clock") }
            .disabled(task.plannedDate == nil)
        if let onEditProject { Button(action: onEditProject) { Label("Проект…", systemImage: "folder") } }
        if let onEditDeadline { Button(action: onEditDeadline) { Label("Дедлайн…", systemImage: "flag") } }
        if let onEditReminder { Button(action: onEditReminder) { Label("Напоминание…", systemImage: "bell") } }
        Divider()
        Button(action: onRename) { Label("Переименовать…", systemImage: "pencil") }
        Button(role: .destructive, action: onDelete) { Label("Удалить…", systemImage: "trash") }
    }
}
