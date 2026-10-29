import SwiftUI
import OrbitCore

struct OrbitTagsScreen: View {
    let model: IOSInboxModel
    var selection: Binding<Set<UUID>>? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitAppearance) private var appearance
    @FocusState private var nameFocused: Bool
    @State private var editingID: UUID?
    @State private var name = ""
    @State private var color = "coral"
    @State private var editing = false
    @State private var deleting: OrbitTag?
    @State private var error: String?
    @State private var editorError: String?
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.2) }
    var body: some View {
        List {
            if let failure = model.tagError { OrbitErrorMessage(failure) }
            if let error { OrbitErrorMessage(error) }
            if model.tags.isEmpty {
                ContentUnavailableView("Пока нет тегов", systemImage: "tag", description: Text("Например, «Важно», «Дом» или «Работа». Теги доступны во всех проектах."))
            }
            Section {
                ForEach(model.tags) { tag in
                    HStack(spacing: 12) {
                        Button {
                            if let selection {
                                withAnimation(animation) {
                                    if selection.wrappedValue.contains(tag.id) { selection.wrappedValue.remove(tag.id) }
                                    else { selection.wrappedValue.insert(tag.id) }
                                }
                                OrbitHaptics.selection()
                            } else { edit(tag) }
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(tint(tag.colorName ?? "coral")).frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tag.name).foregroundStyle(.primary)
                                    Text("Задач: \(model.tasks.filter { ($0.tagIDs ?? []).contains(tag.id) }.count)")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selection?.wrappedValue.contains(tag.id) == true {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orbitAccent)
                                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        Menu {
                            Button("Изменить", systemImage: "pencil") { edit(tag) }
                            Button("Удалить тег", systemImage: "trash", role: .destructive) { deleting = tag }
                        } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                            .accessibilityLabel("Действия с тегом \(tag.name)")
                    }
                    .listRowBackground(appearance.canvas)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 8))
                    .swipeActions {
                        Button("Удалить", role: .destructive) { deleting = tag }
                    }
                }
                Button("Создать тег", systemImage: "plus") {
                    editingID = nil; name = ""; color = "coral"; editorError = nil; editing = true
                }.frame(minHeight: 44)
                    .listRowBackground(appearance.canvas)
            } footer: {
                Text(selection == nil ? "Теги общие для всех проектов. Удаление тега не удаляет задачи." : "Выбор применится при сохранении задачи. Изменения самих тегов сохраняются сразу.")
            }
        }
        .listStyle(.plain)
        .animation(animation, value: model.tags.map(\.id))
        .orbitEditorSurface().navigationTitle("Теги").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editing) {
            NavigationStack {
                ScrollView {
                  VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Название").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("Например, Работа", text: $name)
                            .font(.title3).focused($nameFocused).submitLabel(.done)
                            .onSubmit { nameFocused = false }
                            .padding(16)
                            .background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Цвет").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 12) {
                            ForEach(OrbitTag.colors, id: \.self) { option in
                                Button {
                                    withAnimation(animation) { color = option }
                                    OrbitHaptics.selection()
                                } label: {
                                    ZStack {
                                        Circle().fill(tint(option)).frame(width: 32, height: 32)
                                        if color == option { Image(systemName: "checkmark").font(.body.bold()).foregroundStyle(.white) }
                                    }.frame(width: 48, height: 48).contentShape(Rectangle())
                                }.buttonStyle(.plain).accessibilityLabel(colorTitle(option))
                                    .accessibilityAddTraits(color == option ? .isSelected : [])
                            }
                        }.padding(12)
                            .background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                    if let editorError { OrbitErrorMessage(editorError) }
                  }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollDismissesKeyboard(.interactively)
                .background(appearance.canvas.ignoresSafeArea())
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Готово") { nameFocused = false }
                    }
                }
                .orbitEditorSurface().navigationTitle(editingID == nil ? "Новый тег" : "Изменить тег")
                .navigationBarTitleDisplayMode(.inline)
                .orbitEditorActions(enabled: !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, confirm: "Сохранить", save: {
                    editorError = model.saveTag(name: name, id: editingID, color: color)
                    if editorError == nil { editing = false }
                }, cancel: { editing = false })
            }
            .background(appearance.canvas.ignoresSafeArea())
            .presentationDetents([.large]).presentationDragIndicator(.visible)
        }
        .alert("Удалить тег?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("Удалить", role: .destructive) {
                if let tag = deleting {
                    let id = tag.id
                    withAnimation(animation) { error = model.deleteTag(id: id) }
                    if error == nil { selection?.wrappedValue.remove(id) }
                }
                deleting = nil
            }
            Button("Отмена", role: .cancel) { deleting = nil }
        } message: { Text("Тег будет снят со всех задач. Сами задачи сохранятся. Это действие нельзя отменить.") }
    }
    private func edit(_ tag: OrbitTag) {
        editingID = tag.id; name = tag.name; color = tag.colorName ?? "coral"; editorError = nil; editing = true
    }
    private func tint(_ name: String) -> Color {
        switch name {
        case "orange": .orange
        case "green": .green
        case "blue": .blue
        case "purple": .purple
        case "pink": .pink
        case "gray": .gray
        default: .orbitAccentFill
        }
    }
    private func colorTitle(_ name: String) -> String {
        ["coral": "Коралловый", "orange": "Оранжевый", "green": "Зелёный", "blue": "Синий", "purple": "Фиолетовый", "pink": "Розовый", "gray": "Серый"][name] ?? name
    }
}
