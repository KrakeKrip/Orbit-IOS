import SwiftUI
import OrbitCore

struct OrbitTagsScreen: View {
    let model: IOSInboxModel
    var selection: Binding<Set<UUID>>? = nil
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var editing = false
    @State private var error: String?
    var body: some View {
        Form {
            if let failure = model.tagError { OrbitErrorMessage(failure) }
            if let error { OrbitErrorMessage(error) }
            Section {
                ForEach(model.tags) { tag in
                    HStack {
                        Button {
                            if let selection {
                                if selection.wrappedValue.contains(tag.id) { selection.wrappedValue.remove(tag.id) }
                                else { selection.wrappedValue.insert(tag.id) }
                            } else { edit(tag) }
                        } label: {
                            HStack {
                                Text(tag.name).foregroundStyle(.primary)
                                Spacer()
                                if selection?.wrappedValue.contains(tag.id) == true {
                                    Image(systemName: "checkmark").foregroundStyle(Color.orbitAccent)
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Button { edit(tag) } label: { Image(systemName: "pencil").frame(width: 44, height: 44) }
                            .buttonStyle(.borderless).accessibilityLabel("Переименовать тег \(tag.name)")
                    }
                }
                Button("Создать тег", systemImage: "plus") { editingID = nil; name = ""; editing = true }
            } footer: {
                Text(selection == nil ? "Теги общие для всех проектов." : "Выбор применится при сохранении задачи. Создание и переименование тегов сохраняются сразу для всего приложения.")
            }
        }
        .orbitEditorSurface().navigationTitle("Теги").navigationBarTitleDisplayMode(.inline)
        .alert(editingID == nil ? "Новый тег" : "Переименовать тег", isPresented: $editing) {
            TextField("Название", text: $name)
            Button("Сохранить") { error = model.saveTag(name: name, id: editingID) }
            Button("Отмена", role: .cancel) { }
        } message: { Text("До 120 символов.") }
    }
    private func edit(_ tag: OrbitTag) { editingID = tag.id; name = tag.name; editing = true }
}
