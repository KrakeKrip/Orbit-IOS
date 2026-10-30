import SwiftUI
import OrbitCore

struct OrbitTagsScreen: View {
    let model: IOSInboxModel
    var selection: Binding<Set<UUID>>? = nil
    var projectsContent: AnyView? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitAppearance) private var appearance
    @AppStorage("orbit.ui.tags.expanded") private var tagsExpanded = true
    @State private var editor: TagEditorDraft?
    @State private var browsingTag: OrbitTag?
    @State private var deleting: OrbitTag?
    @State private var error: String?
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.2) }
    var body: some View {
        List {
            if let projectsContent { projectsContent }
            if let failure = model.tagError { OrbitErrorMessage(failure) }
            if let error { OrbitErrorMessage(error) }
            if model.tags.isEmpty && projectsContent == nil {
                ContentUnavailableView("Пока нет тегов", systemImage: "tag", description: Text("Например, «Важно», «Дом» или «Работа». Теги доступны во всех проектах."))
            }
            Section {
                if projectsContent != nil {
                    VStack(spacing: 12) {
                        Divider().padding(.top, 8)
                        OrbitCollapsibleSectionHeader(title: "Теги", expanded: $tagsExpanded,
                                                      createLabel: "Создать тег", identifier: "tags") {
                            editor = TagEditorDraft()
                        }
                    }
                    .listRowBackground(appearance.canvas)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                }
                if projectsContent == nil || tagsExpanded {
                    if model.tags.isEmpty && projectsContent != nil {
                        Text("Пока нет тегов").font(.subheadline).foregroundStyle(.secondary).padding(.vertical, 4)
                            .listRowBackground(appearance.canvas).listRowSeparator(.hidden)
                    }
                    ForEach(model.tags) { tag in
                        HStack(spacing: 12) {
                            Button {
                                if let selection {
                                    withAnimation(animation) {
                                        if selection.wrappedValue.contains(tag.id) { selection.wrappedValue.remove(tag.id) }
                                        else { selection.wrappedValue.insert(tag.id) }
                                    }
                                    OrbitHaptics.selection()
                                } else { browsingTag = tag }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(tint(tag.colorName ?? "coral"))
                                        .frame(width: 22, height: 22)
                                        .frame(width: 28, height: 28)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tag.name).font(.body.weight(.medium)).foregroundStyle(.primary)
                                        Text("Задач: \(model.tasks.filter { ($0.tagIDs ?? []).contains(tag.id) }.count)")
                                            .font(.footnote).foregroundStyle(appearance.secondaryText)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    Spacer()
                                    if selection?.wrappedValue.contains(tag.id) == true {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.orbitAccent)
                                            .transition(.opacity.combined(with: .scale(scale: 0.85)))
                                    }
                                }.padding(.vertical, 4).frame(minHeight: 44, alignment: .leading).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                            Menu {
                                Button("Изменить", systemImage: "pencil") { edit(tag) }
                                Button("Удалить тег", systemImage: "trash", role: .destructive) { deleting = tag }
                            } label: { Image(systemName: "ellipsis").frame(width: 44, height: 44) }
                                .accessibilityLabel("Действия с тегом \(tag.name)")
                        }
                        .listRowBackground(projectsContent == nil ? appearance.surface : appearance.canvas)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(projectsContent != nil && tag.id == model.tags.last?.id ? .hidden : .visible, edges: .bottom)
                        .swipeActions {
                            Button("Удалить", role: .destructive) { deleting = tag }
                        }
                    }
                    if projectsContent == nil {
                        Button("Создать тег", systemImage: "plus") {
                            editor = TagEditorDraft()
                        }.frame(minHeight: 44)
                            .listRowBackground(appearance.surface)
                    }
                }
            }

        }
        .listStyle(.plain)
        .listSectionSeparator(.hidden)
        .scrollBounceBehavior(.always)
        .contentMargins(.top, 8, for: .scrollContent)
        .contentMargins(.bottom, projectsContent == nil ? 0 : 88, for: .scrollContent)
        .orbitMainScrollObserver(enabled: projectsContent != nil)
        .animation(animation, value: model.tags.map(\.id))
        .animation(animation, value: tagsExpanded)
        .orbitEditorSurface().navigationTitle(projectsContent == nil ? "Теги" : "Проекты").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editor) { draft in
            OrbitTagEditor(model: model, draft: draft)
        }
        .sheet(item: $browsingTag) { tag in
            OrbitTagTasksScreen(model: model, tag: tag)
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
        editor = TagEditorDraft(tagID: tag.id, name: tag.name, color: tag.colorName ?? "coral")
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

/// Independent disclosure and add targets; the entire title toggles a section.
struct OrbitCollapsibleSectionHeader: View {
    @Environment(\.orbitAppearance) private var appearance
    let title: String
    @Binding var expanded: Bool
    let createLabel: String
    let identifier: String
    let create: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button { expanded.toggle() } label: {
                HStack(spacing: 8) {
                    Text(title).font(.headline)
                    Image(systemName: expanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(appearance.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(expanded ? "Развёрнуто" : "Свёрнуто")
            .accessibilityHint(expanded ? "Свернуть раздел" : "Развернуть раздел")
            .accessibilityIdentifier("\(identifier)-disclosure")
            Button(action: create) {
                Image(systemName: "plus").frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Color.orbitAccent)
            .accessibilityLabel(createLabel)
            .accessibilityIdentifier("\(identifier)-create")
        }
        .textCase(nil)
    }
}

private struct TagEditorDraft: Identifiable {
    let id = UUID()
    var tagID: UUID? = nil
    var name = ""
    var color = "coral"
}

private struct OrbitTagEditor: View {
    let model: IOSInboxModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var nameFocused: Bool
    private let editingID: UUID?
    @State private var name: String
    @State private var color: String
    @State private var editorError: String?
    private var animation: Animation? { reduceMotion ? nil : .easeInOut(duration: 0.2) }
    init(model: IOSInboxModel, draft: TagEditorDraft) {
        self.model = model; editingID = draft.tagID
        _name = State(initialValue: draft.name)
        _color = State(initialValue: draft.color)
    }
    var body: some View {
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
                    if editorError == nil { dismiss() }
                }, cancel: { dismiss() })
            }
            .background(appearance.canvas.ignoresSafeArea())
            .presentationDetents([.large]).presentationDragIndicator(.visible)
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

private struct OrbitTagTasksScreen: View {
    let model: IOSInboxModel
    let tag: OrbitTag
    @Environment(\.dismiss) private var dismiss
    @Environment(\.orbitAppearance) private var appearance
    @State private var creating = false
    @State private var editor: InboxSheetPresentation?
    private var tasks: [OrbitTask] { model.tasks.filter { ($0.tagIDs ?? []).contains(tag.id) } }
    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    ContentUnavailableView("Нет задач с этим тегом", systemImage: "tag")
                        .listRowBackground(appearance.canvas)
                }
                ForEach([false, true], id: \.self) { completed in
                    let rows = tasks.filter { $0.isCompleted == completed }
                    if !rows.isEmpty {
                        Section(completed ? "Завершённые" : "Открытые") {
                            ForEach(rows) { task in
                                InboxRowView(task: task, model: model) { editor = .date(task) }
                                    onEditInterval: { editor = .interval(task) }
                            }
                        }
                    }
                }
            }
            .listStyle(.plain).orbitEditorSurface()
            .navigationTitle(tag.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Готово") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button("Добавить задачу", systemImage: "plus") { creating = true }
                }
            }
            .sheet(isPresented: $creating) {
                TaskCreateSheet(model: model, datePreset: nil, tagPreset: [tag.id])
            }
            .sheet(item: $editor) { item in
                switch item {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
        }
    }
}
