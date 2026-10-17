import SwiftUI

struct OrbitTaskSelectionHeader: View {
    let model: IOSInboxModel
    var body: some View {
        HStack {
            Button("Отмена") { model.endSelection() }.frame(minHeight: 44)
            Spacer(minLength: 8)
            Text("Выбрано: \(model.selectedTaskIDs.count)").font(.headline)
                .accessibilityIdentifier("task-selection-count")
        }
    }
}

/// Root-level host remains stable while selected rows are changed or deleted.
struct OrbitTaskSelectionActions: View {
    let model: IOSInboxModel
    @State private var confirmingDelete = false
    private var count: Int { model.selectedTaskIDs.count }

    var body: some View {
        VStack(spacing: 8) {
            if let error = model.selectionError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            HStack(spacing: 10) {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Image(systemName: "trash").font(.title3).foregroundStyle(.red)
                        .frame(width: 52, height: 50)
                        .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel("Удалить")
                .accessibilityIdentifier("task-selection-delete")
                Button { model.completeSelection() } label: {
                    Label("Завершить", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .foregroundStyle(.white)
                        .background(Color.orbitAccent, in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityIdentifier("task-selection-complete")
            }
            .buttonStyle(.plain)
            .disabled(count == 0)
            .opacity(count == 0 ? 0.45 : 1)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28))
        .overlay { RoundedRectangle(cornerRadius: 28).stroke(.primary.opacity(0.08), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.10), radius: 16, y: 5)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .confirmationDialog("Удалить выбранные задачи?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Удалить задачи (\(count))", role: .destructive) { model.deleteSelection() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Выбрано: \(count). Это действие нельзя отменить.")
        }
    }
}
