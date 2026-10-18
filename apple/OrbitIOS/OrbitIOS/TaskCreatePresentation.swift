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
                    .tint(.orbitAccent)
            } else {
                Button(action: action) { symbol }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .tint(.orbitAccent)
            }
        }
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var symbol: some View {
        Image(systemName: "plus")
            .font(.system(size: 27, weight: .medium))
            .frame(width: 48, height: 48)
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
                        .allowsHitTesting(enabled && !model.isSelecting)
                        .accessibilityHidden(!enabled || model.isSelecting)
                        .opacity(model.isSelecting ? 0 : 1)
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
        }
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

/// NATIVE-ADD-002/ADD-004: the one create sheet. The host's date preset only
/// seeds a LOCAL editable draft (optional civil date + optional time pair);
/// the user can assign, change or remove the date in any context before
/// saving — wheel writes assign live, and «Выбрать эту дату» explicitly
/// confirms the shown wheel position even without spinning (R1) — while
/// «Отмена»/swipe never write. While the date is unset the time
/// toggle is disabled with «Сначала выберите дату» — nothing is silently
/// dated today; clearing the date also disables the pair in the draft, so
/// «Добавить» then sends nil/nil. Time is enabled explicitly by the user
/// (neutral defaults 09:00 / 30 мин), always as a whole pair, with a
/// remove-time action that keeps the date. The wheels mirror the accepted
/// interval editor: start hours 0...23 / minutes 0...59 (not a step-of-5),
/// duration hours 0...24 with minute options only 0, 5 ... 55 — the write
/// minimum 5...1440 stays a minimum (6/7 valid); 00 ч 00 and 24 ч 05+ drafts
/// disable «Добавить» with a short hint while the core stays the final
/// validation. At most one group (date/start/duration) is expanded at a
/// time; opening a group releases the keyboard and keeps the drafts. The
/// derived «Закончится в …» preview comes from the accepted
/// `TaskTimeInterval.end` with the «(+1 день)» crossing mark and is never
/// stored. Title/store errors appear inside the form and keep every draft
/// for retry; the sheet closes only after a confirmed successful save (a
/// later read failure is not turned back into a write error).
struct TaskCreateSheet: View {
    let model: IOSInboxModel
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
    @FocusState private var titleFieldFocused: Bool
    @State private var title = ""
    @State private var errorMessage: String?
    /// Set only on confirmed success; a repeated submit in the same turn
    /// (double tap) can then never insert a duplicate.
    @State private var created = false

    /// Local draft: optional civil date `YYYY-MM-DD` (nil = undated).
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
    @State private var showsAdditional = false
    @Environment(\.orbitAppearance) private var appearance

    private static let durationMinuteOptions = Array(stride(from: 0, through: 55, by: 5))
    private static let rangeLowerBound = TaskPlannedDate.date(fromCivilDateString: "1900-01-01") ?? Date.distantPast
    private static let rangeUpperBound = TaskPlannedDate.date(fromCivilDateString: "2199-12-31") ?? Date.distantFuture

    init(model: IOSInboxModel, datePreset: String?, projectPreset: UUID? = nil,
         timePreset: String? = nil, durationPreset: Int? = nil) {
        self.model = model
        self.datePreset = datePreset
        _draftProjectID = State(initialValue: projectPreset)
        // The preset seeds the draft only when it is a valid civil date; an
        // invalid preset is never silently replaced by today.
        let seeded = datePreset.flatMap { TaskPlannedDate.isValid($0) ? $0 : nil }
        if let seeded, let timePreset, let durationPreset,
           TaskTimeInterval.isWritableDuration(durationPreset),
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
            Form {
                Section { titleField }
                Section {
                    Picker("Проект", selection: $draftProjectID) {
                        Text("Без проекта").tag(nil as UUID?)
                        ForEach(model.projects) { Text($0.name).tag(Optional($0.id)) }
                    }
                    .accessibilityIdentifier("create-project-picker")
                    dateSection
                    timeSection
                }
                Section {
                    DisclosureGroup("Дополнительно", isExpanded: $showsAdditional) {
                        TaskDeadlineFields(value: $draftDeadline, expanded: Binding(
                            get: { expandedGroup == .deadline },
                            set: { value in
                                titleFieldFocused = false
                                expandedGroup = value ? .deadline : nil
                            }))
                        TaskReminderFields(value: $draftReminder, expanded: Binding(
                            get: { expandedGroup == .reminder },
                            set: { flag in
                                titleFieldFocused = false
                                expandedGroup = flag ? .reminder : nil
                            }), service: model.reminders)
                    }
                    .accessibilityIdentifier("create-additional")
                    .onChange(of: showsAdditional) { _, _ in titleFieldFocused = false }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                            .accessibilityIdentifier("create-error")
                    }
                }
            }
            .listSectionSpacing(.custom(8))
            .contentMargins(.top, 8, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .orbitEditorSurface()
            .safeAreaInset(edge: .top, spacing: 0) { createHeader }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { titleFieldFocused = true }
        }
        // A single detent avoids a downward scroll first shrinking the sheet.
        // The fixed Cancel control stays available with keyboard and wheels.
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .orbitEditorSurface()
    }

    private var createHeader: some View {
        HStack(spacing: 8) {
            Button("Отмена") { titleFieldFocused = false; dismiss() }
                .accessibilityIdentifier("create-cancel-button")
            Spacer(minLength: 0)
            Text("Новая задача").font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            Button("Добавить", action: submit)
                .fontWeight(.semibold)
                .disabled(!addEnabled)
                .accessibilityIdentifier("create-add-button")
        }
        .font(.subheadline)
        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 12)
        .background(appearance.canvas)
    }

    // MARK: - Sections

    private var titleField: some View {
        TextField("Название задачи", text: $title, prompt: Text("Название задачи"))
            .focused($titleFieldFocused)
            .submitLabel(.done)
            .onSubmit(submit)
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
                DatePicker(
                    "Дата",
                    selection: $pickerDate,
                    in: Self.rangeLowerBound...Self.rangeUpperBound,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .environment(\.calendar, Calendar.orbitCivil)
                .accessibilityIdentifier("create-date-picker")
                .onChange(of: pickerDate) { _, newDate in
                    draftDate = TaskPlannedDate.civilDateString(from: newDate)
                }
                // NATIVE-ADD-004-R1: explicit confirmation of the date the
                // wheel currently shows — assigns the draft even when the
                // wheel value did not change. This covers the undated Inbox
                // opening (today already centered) and re-selecting after
                // «Убрать дату» (the wheel keeps its last position). Opening
                // or closing the group alone never assigns anything.
                Button {
                    draftDate = TaskPlannedDate.civilDateString(from: pickerDate)
                } label: {
                    Label("Выбрать эту дату", systemImage: "calendar.badge.checkmark")
                        .frame(maxWidth: .infinity)
                }
                .orbitPrimaryStyle()
                .accessibilityIdentifier("create-confirm-date")
                if draftDate != nil {
                    Button(role: .destructive) {
                        // Clearing the date disables the pair in the draft;
                        // «Добавить» then sends nil/nil.
                        draftDate = nil
                        timeEnabled = false
                    } label: {
                        Label("Убрать дату", systemImage: "calendar.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .orbitSecondaryStyle()
                    .accessibilityIdentifier("create-clear-date")
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
            HStack {
                Toggle("Время", isOn: timeToggleBinding)
                    .disabled(draftDate == nil)
                    .accessibilityIdentifier("create-time-toggle")
            }
            if draftDate == nil {
                Text("Сначала выберите дату")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("create-time-hint")
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
                            ForEach(Self.durationMinuteOptions, id: \.self) { minute in
                                Text("\(minute) мин").tag(minute)
                            }
                        } selection: {
                            $draftDurationMinutes
                        }
                    }
                    .frame(maxWidth: .infinity)
                    if !durationWheelValid {
                        Text(durationRangeHint)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("create-duration-hint")
                    }
                }

                if let preview = endPreview {
                    LabeledContent("Закончится в") {
                        Text(preview)
                    }
                    .accessibilityIdentifier("create-end-preview")
                }

                Button(role: .destructive) {
                    // Remove the whole pair; the date stays.
                    timeEnabled = false
                    expandedGroup = nil
                } label: {
                    Label("Убрать время", systemImage: "clock.badge.minus")
                        .frame(maxWidth: .infinity)
                }
                .orbitSecondaryStyle()
                .accessibilityIdentifier("create-clear-time")
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
        durationWheelValid
            ? RussianDurationText.text(draftDurationTotal)
            : "недопустимая длительность"
    }

    private var durationRangeHint: String {
        "Длительность — от \(TaskTimeInterval.minimumWritableDurationMinutes) минут до \(TaskTimeInterval.maximumDurationMinutes / 60) ч 00 мин."
    }

    /// Read-only derived end from the accepted helper; never stored. The
    /// «Закончится в …» prefix appears exactly once, with the overnight
    /// crossing marked.
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

    private var addEnabled: Bool {
        if isTitleBlank { return false }
        if timeEnabled && !durationWheelValid { return false }
        return true
    }

    /// Explicit user enable: the neutral accepted defaults (09:00 / 30 мин);
    /// the wheels take these values only from this moment on.
    private var timeToggleBinding: Binding<Bool> {
        Binding(
            get: { timeEnabled },
            set: { enabled in
                timeEnabled = enabled
                if enabled {
                    draftStartHour = 9
                    draftStartMinute = 0
                    draftDurationHours = 0
                    draftDurationMinutes = 30
                    expandedGroup = nil
                }
            }
        )
    }

    // MARK: - Actions

    /// At most one group is expanded at a time; opening a group releases the
    /// keyboard while the title and all drafts stay untouched.
    private func toggleGroup(_ group: ExpandedGroup) {
        titleFieldFocused = false
        expandedGroup = expandedGroup == group ? nil : group
    }

    private func submit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // The «Добавить» button is disabled while blank; this guard covers the
        // keyboard submit path with the same refusal.
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Введите название задачи."
            return
        }
        if timeEnabled && !durationWheelValid {
            errorMessage = durationRangeHint
            return
        }
        guard !created else { return }
        // The pair is sent whole only when explicitly enabled on a dated
        // draft; a cleared date always sends nil/nil. The core stays the
        // final validation.
        let sendInterval = timeEnabled && draftDate != nil
        if let message = model.create(
            title: trimmedTitle,
            plannedDate: draftDate,
            plannedTime: sendInterval ? startString : nil,
            durationMinutes: sendInterval ? draftDurationTotal : nil,
            projectID: draftProjectID,
            deadlineDate: draftDeadline,
            reminderAt: draftReminder
        ) {
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
            HStack {
                Text(title)
                Spacer(minLength: 8)
                Text(value)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.orbitAccent)
            }
            .frame(minHeight: 44)
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
                .foregroundStyle(.secondary)
            Picker(title, selection: selection()) {
                options()
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity, minHeight: 120)
        }
        .frame(maxWidth: .infinity)
    }
}
