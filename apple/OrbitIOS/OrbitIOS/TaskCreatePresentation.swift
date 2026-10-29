import SwiftUI
import OrbitCore

/// NATIVE-ADD-002/ADD-004: the one shared creation UI for every section
/// view. The coral circular «+» floats at the bottom trailing edge above the
/// native tab bar (placed in the real bottom safe-area inset, never via
/// UIScreen/device coordinates) and presents the one create sheet. The date
/// preset is fixed by the host at the moment of opening — Inbox is always
/// undated, Today uses the fresh local Gregorian day, Upcoming uses its
/// existing selected day — and only seeds the sheet's editable draft. The
/// sheet itself owns an optional civil date and an optional time interval
/// draft, saved as one whole candidate through the accepted atomic
/// `addTask`; task detail/Projects stay out.
struct OrbitCreateButton: View {
    let action: () -> Void
    var label = "Добавить задачу"
    var identifier = "create-task-fab"

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Button(action: action) { symbol }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(.orbitAccentFill)
            } else {
                Button(action: action) { symbol }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.orbitAccentFill)
            }
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var symbol: some View {
        Image(systemName: "plus")
            .font(.system(size: 24, weight: .medium))
            .frame(width: 40, height: 40)
    }
}

/// Identifiable presentation for the item-based sheet: every opening gets a
/// fresh identity, so the sheet's draft is always local to that opening and
/// is destroyed on close — cancel/swipe never creates or mutates anything.
private struct TaskCreateSheetPresentation: Identifiable {
    let id = UUID()
    /// The civil date fixed for this opening (`nil` = undated Inbox task).
    let datePreset: String?
    var projectPreset: UUID? = nil
}

private struct OrbitCreateHostModifier: ViewModifier {
    let model: IOSInboxModel
    /// Evaluated at tap time so the preset is the day at the moment of
    /// opening, never a value captured earlier by the host.
    let datePreset: () -> String?
    var projectPreset: UUID? = nil

    @State private var presentation: TaskCreateSheetPresentation?

    func body(content: Content) -> some View {
        content
            .orbitFloatingAction(enabled: presentation == nil) {
                OrbitHaptics.selection()
                presentation = TaskCreateSheetPresentation(datePreset: datePreset(), projectPreset: projectPreset)
            }
            .sheet(item: $presentation) { item in
                TaskCreateSheet(model: model, datePreset: item.datePreset, projectPreset: item.projectPreset)
            }
    }
}

/// One safe-area placement shared by task and project creation.
private struct OrbitFloatingActionModifier: ViewModifier {
    @State private var calendarEditing = false
    @Environment(IOSInboxModel.self) private var model
    let label: String
    let identifier: String
    let enabled: Bool
    let action: () -> Void
    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: 0)
                .overlay(alignment: .bottomTrailing) {
                    OrbitCreateButton(action: action, label: label, identifier: identifier)
                        .allowsHitTesting(enabled && !model.isSelecting && !calendarEditing)
                        .accessibilityHidden(!enabled || model.isSelecting || calendarEditing)
                        .opacity(model.isSelecting || calendarEditing ? 0 : 1)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
        }
        .onPreferenceChange(OrbitCalendarEditingKey.self) { calendarEditing = $0 }
    }
}

extension View {
    func orbitFloatingAction(label: String = "Добавить задачу",
                             identifier: String = "create-task-fab",
                             enabled: Bool = true,
                             action: @escaping () -> Void) -> some View {
        modifier(OrbitFloatingActionModifier(label: label, identifier: identifier,
                                             enabled: enabled, action: action))
    }

    /// Hosts the shared «+» and create sheet over a section view. Applied
    /// once per section host (Inbox, Today workspace, Upcoming workspace) so
    /// the list and calendar presentations share the same composition.
    func orbitCreateAction(
        model: IOSInboxModel,
        datePreset: @escaping () -> String?
    ) -> some View {
        modifier(OrbitCreateHostModifier(model: model, datePreset: datePreset))
    }
}

/// Shared task draft. Content and subtasks lead; schedule and organization
/// remain visible on the root. Parameter screens edit this same local draft,
/// and only the root confirmation writes it to the store.
struct TaskCreateSheet: View {
    let model: IOSInboxModel
    private let editingTask: OrbitTask?
    /// The host's civil date at the moment of opening; only seeds the draft.
    let datePreset: String?

    private enum ExpandedGroup: Equatable {
        case date
        case deadline
        case reminder
        case start
        case duration
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private enum EditorFocus: Hashable { case title, newSubtask, subtask(UUID) }
    private enum Parameter: String, Identifiable {
        case date, time, reminder, repeatRule, deadline, tags
        var id: String { rawValue }
    }
    @FocusState private var focusedField: EditorFocus?
    @State private var parameter: Parameter?
    @State private var addingSubtask = false
    @State private var title = ""
    @State private var draftSubtasks: [TaskSubtask] = []
    @State private var draftRepeat: TaskRepeat?
    @State private var subtaskTitle = ""
    @State private var errorMessage: String?
    /// Set only on confirmed success; a repeated submit in the same turn
    /// (double tap) can then never insert a duplicate.
    @State private var created = false

    /// Local draft: optional civil date `YYYY-MM-DD` (nil = undated).
    @State private var draftTagIDs: Set<UUID> = []
    @State private var draftProjectID: UUID?
    @State private var draftReminder: Date?
    @State private var draftDeadline: String?
    @State private var draftDate: String?
    /// Resting position of the date wheel; only wheel writes touch the
    /// draft. An unset/invalid preset leaves the draft undated while the
    /// wheel still needs a position.
    @State private var pickerDate: Date
    /// The time pair exists in the draft only after the user enables it
    /// explicitly; clearing the date turns it off again.
    @State private var timeEnabled = false
    @State private var draftStartHour = 9
    @State private var draftStartMinute = 0
    @State private var draftDurationHours = 0
    @State private var draftDurationMinutes = 30
    @State private var expandedGroup: ExpandedGroup?
    @State private var confirmsDelete = false
    @State private var confirmsDiscard = false
    @State private var initialDraft: DraftSnapshot?
    @Environment(\.orbitAppearance) private var appearance

    private struct DraftSnapshot: Equatable {
        var title: String
        var date: String?
        var time: String?
        var duration: Int?
        var project: UUID?
        var tags: Set<UUID>
        var deadline: String?
        var reminder: Date?
        var subtasks: [TaskSubtask]
        var pendingSubtask: String
        var repeatRule: TaskRepeat?
    }
    private var draftSnapshot: DraftSnapshot {
        DraftSnapshot(title: title, date: draftDate,
                      time: timeEnabled ? startString : nil,
                      duration: timeEnabled ? draftDurationTotal : nil,
                      project: draftProjectID, tags: draftTagIDs, deadline: draftDeadline,
                      reminder: draftReminder, subtasks: draftSubtasks,
                      pendingSubtask: subtaskTitle, repeatRule: draftRepeat)
    }
    private var hasUnsavedChanges: Bool {
        initialDraft.map { $0 != draftSnapshot } ?? false
    }

    private var durationMinuteOptions: [Int] {
        let standard = Array(stride(from: 0, through: 55, by: 5))
        guard let minutes = editingTask?.durationMinutes else { return standard }
        return Array(Set(standard + [minutes % 60])).sorted()
    }
    private static let rangeLowerBound = TaskPlannedDate.date(fromCivilDateString: "1900-01-01") ?? Date.distantPast
    private static let rangeUpperBound = TaskPlannedDate.date(fromCivilDateString: "2199-12-31") ?? Date.distantFuture

    init(model: IOSInboxModel, datePreset: String?, projectPreset: UUID? = nil,
         timePreset: String? = nil, durationPreset: Int? = nil, editingTask: OrbitTask? = nil) {
        self.model = model
        self.editingTask = editingTask
        let datePreset = editingTask?.plannedDate ?? datePreset
        let timePreset = editingTask?.plannedTime ?? timePreset
        let durationPreset = editingTask?.durationMinutes ?? durationPreset
        self.datePreset = datePreset
        _draftSubtasks = State(initialValue: editingTask?.subtasks ?? [])
        _draftRepeat = State(initialValue: editingTask?.repeatRule)
        _title = State(initialValue: editingTask?.title ?? "")
        _draftReminder = State(initialValue: editingTask?.reminderAt)
        _draftDeadline = State(initialValue: editingTask?.deadlineDate)
        _draftTagIDs = State(initialValue: Set(editingTask?.tagIDs ?? []))
        _draftProjectID = State(initialValue: editingTask?.projectID ?? projectPreset)
        // The preset seeds the draft only when it is a valid civil date; an
        // invalid preset is never silently replaced by today.
        let seeded = datePreset.flatMap { TaskPlannedDate.isValid($0) ? $0 : nil }
        if let seeded, let timePreset, let durationPreset,
           (TaskTimeInterval.isWritableDuration(durationPreset) || (editingTask != nil && TaskTimeInterval.isValidDuration(durationPreset))),
           TaskTimeInterval.end(plannedDate: seeded, plannedTime: timePreset, durationMinutes: durationPreset) != nil {
            let parts = timePreset.split(separator: ":").compactMap { Int($0) }
            _timeEnabled = State(initialValue: true)
            _draftStartHour = State(initialValue: parts[0])
            _draftStartMinute = State(initialValue: parts[1])
            _draftDurationHours = State(initialValue: durationPreset / 60)
            _draftDurationMinutes = State(initialValue: durationPreset % 60)
        }
        _draftDate = State(initialValue: seeded)
        _pickerDate = State(
            initialValue: seeded.flatMap { TaskPlannedDate.date(fromCivilDateString: $0) } ?? .now
        )
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        taskContent
                        editorGroup("План") {
                            parameterButton("Дата", value: draftDateCaption, icon: "calendar", target: .date)
                            rowDivider
                            parameterButton("Время", value: timeEnabled ? intervalSummary : "Без времени", icon: "clock", target: .time)
                                .accessibilityIdentifier("create-interval-summary")
                            rowDivider
                            parameterButton("Напоминание", value: draftReminder.map(TaskReminderFields.caption) ?? "Не напоминать", icon: "bell", target: .reminder)
                            rowDivider
                            parameterButton("Повтор", value: draftRepeat?.title ?? "Не повторять", icon: "repeat", target: .repeatRule)
                        }
                        editorGroup("Детали") {
                            Menu {
                                Picker("Проект", selection: $draftProjectID) {
                                    Text("Без проекта").tag(nil as UUID?)
                                    ForEach(model.projects) { Text($0.name + ($0.isArchived ? " · Архив" : "")).tag(Optional($0.id)) }
                                }
                            } label: {
                                parameterLabel("Проект", value: model.projects.first { $0.id == draftProjectID }.map { $0.name + ($0.isArchived ? " · Архив" : "") } ?? "Без проекта", icon: "folder")
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("create-project-picker")
                            rowDivider
                            parameterButton("Теги", value: tagCaption, icon: "tag", target: .tags)
                            rowDivider
                            parameterButton("Дедлайн", value: draftDeadline.map(RussianDateCaption.label) ?? "Без срока", icon: "flag", target: .deadline)
                        }
                        if let editingTask {
                            VStack(spacing: 8) {
                                Button { submit(completed: !editingTask.isCompleted) } label: {
                                    Label(completionCaption, systemImage: editingTask.isCompleted ? "arrow.uturn.backward" : "checkmark.circle")
                                        .frame(maxWidth: .infinity, minHeight: 44)
                                }
                                .disabled(!addEnabled)
                                .accessibilityIdentifier("task-editor-completion")
                                Button("Удалить задачу…", role: .destructive) { confirmsDelete = true }
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .accessibilityIdentifier("task-editor-delete")
                            }
                        }
                        if let errorMessage {
                            OrbitErrorMessage(errorMessage)
                                .accessibilityIdentifier("create-error")
                                .id("create-error")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: addingSubtask)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: draftSubtasks.map(\.id))
                }
                .scrollDismissesKeyboard(.interactively)
                .orbitEditorSurface()
                .navigationTitle(editingTask == nil ? "Новая задача" : "Задача")
                .navigationBarTitleDisplayMode(.inline)
                .orbitEditorActions(enabled: addEnabled, confirm: editingTask == nil ? "Добавить" : "Сохранить", save: { submit() }, cancel: { requestClose() })
                .navigationDestination(item: $parameter) { target in
                    parameterContent(target)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Закрыть", systemImage: "xmark") { requestClose() }
                                    .labelStyle(.iconOnly)
                            }
                        }
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if focusedField != nil {
                        HStack {
                            Spacer()
                            Button { focusedField = nil } label: {
                                Label("Готово", systemImage: "keyboard.chevron.compact.down")
                                    .frame(minHeight: 44)
                            }
                            .accessibilityLabel("Скрыть клавиатуру")
                            .padding(.horizontal, 20)
                        }
                        .background(appearance.canvas)
                    }
                }
                .onChange(of: focusedField) { _, field in
                    if field != .newSubtask && subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        addingSubtask = false
                    }
                }
                .onAppear {
                    if initialDraft == nil {
                        initialDraft = draftSnapshot
                        if editingTask == nil { focusedField = .title }
                    }
                }
                .onChange(of: errorMessage) { _, message in
                    if message != nil {
                        focusedField = nil
                        scroll.scrollTo("create-error", anchor: .bottom)
                    }
                }
            }
        }
        // A single detent avoids a downward scroll first shrinking the sheet.
        // The fixed Cancel control stays available with keyboard and wheels.
        .alert("Удалить задачу?", isPresented: $confirmsDelete) {
            Button("Удалить", role: .destructive) {
                if let editingTask {
                    model.delete(editingTask)
                    if let message = model.writeError { errorMessage = message }
                    else { dismiss() }
                }
            }
            Button("Отмена", role: .cancel) { }
        } message: { Text("Удаление можно отменить сразу после закрытия редактора. Изменения черновика не сохранятся.") }
        .background(TaskEditorDismissObserver(blocked: hasUnsavedChanges && !created) { requestClose() })
        .interactiveDismissDisabled(hasUnsavedChanges && !created)
        .alert("Закрыть без сохранения?", isPresented: $confirmsDiscard) {
            Button("Сбросить", role: .destructive) { dismiss() }
            Button("Продолжить редактирование", role: .cancel) { }
        } message: { Text("Изменения этой задачи не сохранятся.") }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .orbitEditorSurface()
    }

    private func requestClose() {
        focusedField = nil
        if hasUnsavedChanges { confirmsDiscard = true } else { dismiss() }
    }

    // MARK: - Sections

    private var taskContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            titleField.padding(.bottom, 4)
            if editingTask == nil, let suggestion = TaskQuickInput.parse(title) {
                Button {
                    title = suggestion.title
                    if let day = suggestion.day {
                        draftDate = day
                        pickerDate = TaskPlannedDate.date(fromCivilDateString: day) ?? .now
                    }
                    if let time = suggestion.time, let duration = suggestion.duration {
                        let parts = time.split(separator: ":").compactMap { Int($0) }
                        timeEnabled = true
                        draftStartHour = parts[0]; draftStartMinute = parts[1]
                        draftDurationHours = duration / 60; draftDurationMinutes = duration % 60
                    }
                } label: {
                    Label("Применить: " + [suggestion.day.map { RussianDateCaption.label($0) }, suggestion.time, suggestion.duration.map { "\($0) мин" }].compactMap { $0 }.joined(separator: " · "), systemImage: "text.badge.checkmark")
                        .font(.footnote).frame(minHeight: 44)
                }
                .accessibilityIdentifier("quick-input-apply")
            }
            ForEach($draftSubtasks) { $subtask in
                HStack(alignment: .top, spacing: 4) {
                    Button { subtask.completed.toggle() } label: {
                        Image(systemName: subtask.completed ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(subtask.completed ? Color.orbitAccent : appearance.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(subtask.completed ? "Вернуть подзадачу" : "Выполнить подзадачу")
                    TextField("Подзадача", text: $subtask.title, axis: .vertical)
                        .focused($focusedField, equals: .subtask(subtask.id))
                        .frame(minHeight: 44)
                    Button(role: .destructive) { draftSubtasks.removeAll { $0.id == subtask.id } } label: {
                        Image(systemName: "minus.circle").frame(width: 44, height: 44)
                    }.buttonStyle(.plain).accessibilityLabel("Удалить подзадачу")
                }
            }
            if addingSubtask {
                HStack(spacing: 4) {
                    Image(systemName: "circle").foregroundStyle(appearance.secondaryText).frame(width: 44, height: 44)
                    TextField("Новая подзадача", text: $subtaskTitle)
                        .focused($focusedField, equals: .newSubtask)
                        .submitLabel(.next)
                        .onSubmit(appendSubtask)
                        .accessibilityIdentifier("create-subtask-title")
                    Button(action: appendSubtask) {
                        Image(systemName: "plus.circle.fill").frame(width: 44, height: 44)
                    }
                    .disabled(subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftSubtasks.count >= 100)
                    .accessibilityLabel("Добавить подзадачу")
                }
            }
            if !addingSubtask {
                Button {
                    addingSubtask = true
                    focusedField = .newSubtask
                } label: {
                    Label("Подзадача", systemImage: "plus")
                        .frame(minHeight: 44)
                }
                .disabled(draftSubtasks.count >= 100)
                .accessibilityIdentifier("create-add-subtask")
            }
        }
    }

    private func appendSubtask() {
        let value = subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, draftSubtasks.count < 100 else { return }
        draftSubtasks.append(TaskSubtask(title: value))
        subtaskTitle = ""
        if draftSubtasks.count == 100 { addingSubtask = false; focusedField = nil }
    }

    private var tagCaption: String {
        let names = model.tags.filter { draftTagIDs.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Добавить" : names.joined(separator: ", ")
    }

    private func editorGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption).foregroundStyle(appearance.secondaryText)
                .padding(.leading, 4)
            VStack(spacing: 0, content: content)
                .background(appearance.surface, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private var rowDivider: some View { Divider().padding(.leading, 48).padding(.trailing, 16) }

    private func parameterLabel(_ title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).frame(width: 20)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(title).fixedSize()
                    Spacer(minLength: 8)
                    Text(value).foregroundStyle(appearance.secondaryText).fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                    Text(value).foregroundStyle(appearance.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "chevron.right").font(.caption.weight(.medium))
                .foregroundStyle(appearance.secondaryText)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 2).padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    private func parameterButton(_ title: String, value: String, icon: String, target: Parameter) -> some View {
        Button {
            focusedField = nil
            switch target {
            case .date: expandedGroup = .date
            case .time:
                // Tapping the time row assigns the draft interval directly;
                // no second enable toggle. An undated task stays undated.
                if draftDate != nil { timeEnabled = true }
                expandedGroup = .start
            case .deadline: expandedGroup = .deadline
            case .reminder: expandedGroup = .reminder
            default: expandedGroup = nil
            }
            parameter = target
        } label: { parameterLabel(title, value: value, icon: icon) }
        .buttonStyle(.plain)
        .accessibilityIdentifier("create-parameter-" + target.rawValue)
    }

    @ViewBuilder private func parameterContent(_ target: Parameter) -> some View {
        switch target {
        case .tags:
            OrbitTagsScreen(model: model, selection: $draftTagIDs)
        default:
            Form {
                switch target {
                case .date: Section { dateSection }
                case .time: Section { timeSection }
                case .reminder:
                    Section {
                        TaskReminderFields(value: $draftReminder, expanded: Binding(
                            get: { expandedGroup == .reminder },
                            set: { expandedGroup = $0 ? .reminder : nil }),
                            service: model.reminders, plannedDate: draftDate,
                            plannedTime: timeEnabled ? startString : nil)
                    }
                case .deadline:
                    Section {
                        TaskDeadlineFields(value: $draftDeadline, expanded: Binding(
                            get: { expandedGroup == .deadline },
                            set: { expandedGroup = $0 ? .deadline : nil }))
                    }
                case .repeatRule:
                    Section {
                        Picker("Повтор", selection: $draftRepeat) {
                            Text("Не повторять").tag(nil as TaskRepeat?)
                            ForEach(TaskRepeat.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                        }.pickerStyle(.inline).disabled(draftDate == nil)
                    } footer: {
                        Text(draftDate == nil ? "Сначала выберите дату задачи." : "После выполнения создаётся ближайший повтор позже сегодняшнего дня. Пропущенные дни не накапливаются. Напоминание переносится вместе с датой, дедлайн — нет.")
                    }
                case .tags: EmptyView()
                }
            }
            .orbitEditorSurface()
            .navigationTitle(parameterTitle(target))
            .navigationBarTitleDisplayMode(.inline)
            // Native Form rows and UIKit wheels must not inherit a layout animation.
            .transaction { $0.animation = nil }
        }
    }

    private func parameterTitle(_ target: Parameter) -> String {
        switch target {
        case .date: "Дата"
        case .time: "Время"
        case .reminder: "Напоминание"
        case .repeatRule: "Повтор"
        case .deadline: "Дедлайн"
        case .tags: "Теги"
        }
    }

    private var titleField: some View {
        TextField("Название задачи", text: $title, axis: .vertical)
            .lineLimit(1...4)
            .font(.title2.weight(.semibold))
            .focused($focusedField, equals: .title)
            .accessibilityIdentifier("create-title-field")
    }

    /// Date summary row; expanding it shows the native date wheel (civil
    /// components only, 1900...2199, Russian captions) and, when a date is
    /// drafted, the remove action. The visible caption follows the draft.
    @ViewBuilder
    private var dateSection: some View {
        VStack(spacing: 12) {
            summaryRow(title: "Дата", value: draftDateCaption, expanded: expandedGroup == .date) {
                toggleGroup(.date)
            }
            if expandedGroup == .date {
                Toggle("Назначить дату", isOn: Binding(get: { draftDate != nil }, set: { enabled in
                    draftDate = enabled ? TaskPlannedDate.civilDateString(from: pickerDate) : nil
                    if !enabled { timeEnabled = false; draftRepeat = nil }
                }))
                if draftDate == nil {
                    Text("Без даты. Включите дату, чтобы выбрать день.").font(.footnote).foregroundStyle(appearance.secondaryText)
                }
                DatePicker(
                    "Дата",
                    selection: $pickerDate,
                    in: Self.rangeLowerBound...Self.rangeUpperBound,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden().disabled(draftDate == nil)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .environment(\.calendar, Calendar.orbitCivil)
                .accessibilityIdentifier("create-date-picker")
                .onChange(of: pickerDate) { _, newDate in
                    if draftDate != nil { draftDate = TaskPlannedDate.civilDateString(from: newDate) }
                }

            }
        }
    }

    /// Optional time pair: disabled with a short hint until a date exists
    /// (never silently dated today), enabled explicitly by the user with the
    /// neutral defaults; always a whole pair with a remove-time action that
    /// keeps the date.
    @ViewBuilder
    private var timeSection: some View {
        VStack(spacing: 12) {
            if draftDate == nil {
                Text("Сначала выберите дату")
                    .font(.footnote)
                    .foregroundStyle(appearance.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("create-time-hint")
            }
            if !timeEnabled, draftDate != nil {
                Button("Назначить время") { timeEnabled = true; expandedGroup = .start }
            }
            if timeEnabled {
                summaryRow(title: "Начало", value: startString, expanded: expandedGroup == .start) {
                    toggleGroup(.start)
                }
                if expandedGroup == .start {
                    HStack(alignment: .top, spacing: 0) {
                        wheelColumn("Часы") {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        } selection: {
                            $draftStartHour
                        }
                        wheelColumn("Минуты") {
                            ForEach(0..<60, id: \.self) { minute in
                                Text(String(format: "%02d", minute)).tag(minute)
                            }
                        } selection: {
                            $draftStartMinute
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                summaryRow(
                    title: "Длительность",
                    value: durationSummary,
                    expanded: expandedGroup == .duration
                ) {
                    toggleGroup(.duration)
                }
                if expandedGroup == .duration {
                    HStack(alignment: .top, spacing: 0) {
                        wheelColumn("Часы") {
                            ForEach(0...24, id: \.self) { hour in
                                Text("\(hour) ч").tag(hour)
                            }
                        } selection: {
                            $draftDurationHours
                        }
                        wheelColumn("Минуты") {
                            ForEach(durationMinuteOptions, id: \.self) { minute in
                                Text("\(minute) мин").tag(minute)
                            }
                        } selection: {
                            $draftDurationMinutes
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !validEditorDuration {
                        Text(durationRangeHint)
                            .font(.footnote)
                            .foregroundStyle(Color.orbitError)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("create-duration-hint")
                    }
                }

                Button("Без времени") { timeEnabled = false; parameter = nil }
                    .accessibilityIdentifier("create-remove-time")
                if let preview = endPreview {
                    LabeledContent("Закончится в") {
                        Text(preview)
                    }
                    .accessibilityIdentifier("create-end-preview")
                }


            }
        }
    }

    // MARK: - Draft values

    private var draftDateCaption: String {
        guard let draftDate else { return "Без даты" }
        return RussianDateCaption.label(draftDate)
    }

    private var startString: String {
        String(format: "%02d:%02d", draftStartHour, draftStartMinute)
    }

    private var draftDurationTotal: Int {
        draftDurationHours * 60 + draftDurationMinutes
    }

    /// Whether the wheel combination is a writable duration (5...1440). The
    /// core stays the final validation on save; this only disables
    /// «Добавить» for drafts the rule can never accept (00 ч 00, 24 ч 05…).
    private var durationWheelValid: Bool {
        TaskTimeInterval.isWritableDuration(draftDurationTotal)
    }

    private var durationSummary: String {
        validEditorDuration
            ? RussianDurationText.text(draftDurationTotal)
            : "недопустимая длительность"
    }

    private var durationRangeHint: String {
        "Длительность — от \(TaskTimeInterval.minimumWritableDurationMinutes) минут до \(TaskTimeInterval.maximumDurationMinutes / 60) ч 00 мин."
    }

    /// Read-only derived end from the accepted helper; never stored. The
    /// «Закончится в …» prefix appears exactly once, with the overnight
    /// crossing marked.
    private var intervalSummary: String {
        guard let endPreview else { return startString }
        return "\(startString)–\(endPreview)"
    }

    private var endPreview: String? {
        guard timeEnabled, let draftDate,
            let end = TaskTimeInterval.end(
                plannedDate: draftDate,
                plannedTime: startString,
                durationMinutes: draftDurationTotal
            )
        else { return nil }
        let crossing = end.date != draftDate ? " (+1 день)" : ""
        return "\(end.time)\(crossing)"
    }

    private var isTitleBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var validEditorDuration: Bool {
        durationWheelValid || (editingTask?.durationMinutes == draftDurationTotal && draftDate == editingTask?.plannedDate && startString == editingTask?.plannedTime && TaskTimeInterval.isValidDuration(draftDurationTotal))
    }

    private var draftChanged: Bool {
        guard let task = editingTask else { return false }
        return title != task.title || draftDate != task.plannedDate ||
            (timeEnabled ? startString : nil) != task.plannedTime ||
            (timeEnabled ? draftDurationTotal : nil) != task.durationMinutes ||
            !subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftSubtasks != task.subtasks || draftRepeat != task.repeatRule || draftTagIDs != Set(task.tagIDs ?? []) || draftProjectID != task.projectID || draftDeadline != task.deadlineDate || draftReminder != task.reminderAt
    }

    private var completionCaption: String {
        guard let task = editingTask else { return "Завершить" }
        if task.isCompleted { return draftChanged ? "Сохранить и снова открыть" : "Снова открыть" }
        return draftChanged ? "Сохранить и завершить" : "Завершить"
    }

    private var addEnabled: Bool {
        if isTitleBlank || title.unicodeScalars.count > TaskTitle.maximumLength || created { return false }
        if timeEnabled && !validEditorDuration { return false }
        return true
    }

    // MARK: - Actions

    /// At most one group is expanded at a time; opening a group releases the
    /// keyboard while the title and all drafts stay untouched.
    private func toggleGroup(_ group: ExpandedGroup) {
        focusedField = nil
        expandedGroup = expandedGroup == group ? nil : group
    }

    private func submit(completed: Bool? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // The «Добавить» button is disabled while blank; this guard covers the
        // keyboard submit path with the same refusal.
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Введите название задачи."
            return
        }
        if timeEnabled && !validEditorDuration {
            errorMessage = durationRangeHint
            return
        }
        guard !created else { return }
        // The pair is sent whole only when explicitly enabled on a dated
        // draft; a cleared date always sends nil/nil. The core stays the
        // final validation.
        let pendingSubtask = subtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedSubtasks = draftSubtasks + (pendingSubtask.isEmpty ? [] : [TaskSubtask(title: pendingSubtask)])
        let sendInterval = timeEnabled && draftDate != nil
        let message: String?
        if let editingTask {
            message = model.updateTask(editingTask, title: trimmedTitle, date: draftDate,
                                       time: sendInterval ? startString : nil,
                                       duration: sendInterval ? draftDurationTotal : nil,
                                       project: draftProjectID, deadline: draftDeadline,
                                       reminder: draftReminder, completed: completed, tagIDs: Array(draftTagIDs), subtasks: submittedSubtasks, repeatRule: draftRepeat, updateRepeat: true)
        } else {
            message = model.create(title: trimmedTitle, plannedDate: draftDate,
                                   plannedTime: sendInterval ? startString : nil,
                                   durationMinutes: sendInterval ? draftDurationTotal : nil,
                                   projectID: draftProjectID, deadlineDate: draftDeadline,
                                   reminderAt: draftReminder, tagIDs: Array(draftTagIDs), subtasks: submittedSubtasks, repeatRule: draftRepeat)
        }
        if let message {
            // The sheet and every draft stay up for retry; the list itself
            // was rolled back to persisted truth by the model.
            errorMessage = message
        } else {
            created = true
            dismiss()
        }
    }

    // MARK: - Pieces (mirroring the accepted interval editor)

    private func summaryRow(
        title: String,
        value: String,
        expanded: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            OrbitEditorSummary(title: title, value: value, expanded: expanded)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private func wheelColumn(
        _ title: String,
        @ViewBuilder options: () -> some View,
        selection: () -> Binding<Int>
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(appearance.secondaryText)
            Picker(title, selection: selection()) {
                options()
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .frame(maxWidth: .infinity)
    }
}


/// Reports a blocked sheet swipe instead of silently bouncing the draft back.
private struct TaskEditorDismissObserver: UIViewControllerRepresentable {
    let blocked: Bool
    let onAttempt: () -> Void
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.blocked = blocked
        controller.onAttempt = onAttempt
        controller.attach()
    }
    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var blocked = false
        var onAttempt: (() -> Void)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); attach() }
        override func didMove(toParent parent: UIViewController?) { super.didMove(toParent: parent); attach() }
        func attach() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                var owner: UIViewController? = self.parent
                while let current = owner {
                    if let presentation = current.presentationController, current.presentingViewController != nil {
                        presentation.delegate = self
                        return
                    }
                    owner = current.parent
                }
            }
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { !blocked }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt?() }
    }
}
