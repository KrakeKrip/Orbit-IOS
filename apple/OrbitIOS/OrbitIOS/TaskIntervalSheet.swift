import SwiftUI
import OrbitCore

/// Small time-interval editor for one dated task (NATIVE-TIME-WHEEL):
/// «Начало» and «Длительность» are compact tappable summary rows; tapping a
/// row expands its native wheel group (at most one group is expanded at a
/// time). Start uses hour 0...23 and minute 0...59 wheels — civil wall-clock
/// components only, no date→instant/DST path. Duration uses an hour wheel
/// 0...24 and a minute wheel offering only 0, 5, 10 ... 55 (the user's step
/// for NEW choices); 00 ч 00 is below the writable minimum and 24 ч 05 and
/// above exceed the 24 ч 00 maximum — such drafts disable «Сохранить» with a
/// short hint, while the core stays the final validation.
/// Legacy stored durations that are not representable on the 5-minute wheel
/// (1...4, 6, 7, 61 ...) are shown as an exact readable «Сохранено: …»
/// summary and are never rounded or hidden; the wheels only take effect for
/// Save after the user explicitly moves them. Opening, expanding, swiping
/// and «Отмена» never write; a failed save shows the existing Russian error
/// and keeps the draft. The derived «Закончится в …» preview is read-only
/// via the accepted `TaskTimeInterval.end` and is never stored.
struct TaskIntervalSheet: View {
    let task: OrbitTask
    let model: IOSInboxModel

    private enum ExpandedGroup: Equatable {
        case start
        case duration
    }

    @Environment(\.dismiss) private var dismiss
    @State private var draftStartHour: Int
    @State private var draftStartMinute: Int
    @State private var draftDurationHours: Int
    @State private var draftDurationMinutes: Int
    /// Exact stored duration when it cannot be represented on the 5-minute
    /// wheel (NATIVE-MIN5 legacy compatibility); nil for representable/absent.
    @State private var legacyDurationMinutes: Int?
    /// Whether the user has explicitly moved a duration wheel (until then the
    /// legacy stored value remains the effective draft).
    @State private var durationWheelActive = false
    @State private var expandedGroup: ExpandedGroup?
    @State private var removesInterval = false
    @State private var errorMessage: String?

    private static let durationMinuteOptions = Array(stride(from: 0, through: 55, by: 5))

    init(task: OrbitTask, model: IOSInboxModel) {
        self.task = task
        self.model = model

        let savedStart = task.plannedTime ?? "09:00"
        let startChars = Array(savedStart)
        let savedHour = startChars.count == 5 ? (Int(String(startChars[0...1])) ?? 9) : 9
        let savedMinute = startChars.count == 5 ? (Int(String(startChars[3...4])) ?? 0) : 0
        _draftStartHour = State(initialValue: min(max(savedHour, 0), 23))
        _draftStartMinute = State(initialValue: min(max(savedMinute, 0), 59))

        if let saved = task.durationMinutes {
            if saved % 5 == 0 {
                _draftDurationHours = State(initialValue: min(saved / 60, 24))
                _draftDurationMinutes = State(initialValue: saved % 60)
                _legacyDurationMinutes = State(initialValue: nil)
            } else {
                // Off-grid legacy value (1...4, 6, 7, 61 ...): keep it as the
                // effective draft; the wheels seed at the neutral default and
                // take effect only after the user explicitly moves them.
                _draftDurationHours = State(initialValue: 0)
                _draftDurationMinutes = State(initialValue: 30)
                _legacyDurationMinutes = State(initialValue: saved)
            }
        } else {
            _draftDurationHours = State(initialValue: 0)
            _draftDurationMinutes = State(initialValue: 30)
            _legacyDurationMinutes = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(task.title)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("interval-task-title")
                } header: {
                    Text("Задача")
                }

                Section {
                    summaryRow(title: "Начало", value: startString, expanded: expandedGroup == .start) {
                        expandedGroup = expandedGroup == .start ? nil : .start
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
                        value: durationSummaryText,
                        expanded: expandedGroup == .duration
                    ) {
                        expandedGroup = expandedGroup == .duration ? nil : .duration
                    }
                    if expandedGroup == .duration {
                        if savedDurationOffGrid, let legacy = legacyDurationMinutes {
                            Text("Сохранено: \(RussianDurationText.text(legacy)) — выберите новую длительность, кратную 5 минутам.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
                        .onChange(of: draftDurationHours) { _, _ in durationWheelActive = true }
                        .onChange(of: draftDurationMinutes) { _, _ in durationWheelActive = true }
                        if !durationWheelValid {
                            Text(durationRangeHint)
                                .font(.footnote)
                                .foregroundStyle(Color.orbitError)
                        }
                    }
                }

                if removesInterval {
                    Text("После сохранения задача останется без времени; дата сохранится.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Дата") {
                        Text(dateContext)
                    }
                    if let preview = endPreview {
                        LabeledContent("Закончится в") {
                            Text(preview)
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        OrbitErrorMessage(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.orbitError)
                            .accessibilityIdentifier("interval-error")
                    }
                }

                Section {
                    if task.plannedTime != nil {
                        Button { removesInterval.toggle() } label: {
                            Label(removesInterval ? "Восстановить время" : "Без времени", systemImage: "clock.badge.minus")
                                .frame(maxWidth: .infinity)
                        }
                        .accessibilityIdentifier("interval-clear")
                    }
                }
            }
            .orbitEditorSurface()
            .navigationTitle("Время задачи")
            .navigationBarTitleDisplayMode(.inline)
            .orbitEditorActions(enabled: removesInterval || saveEnabled, save: { if removesInterval { clearInterval() } else { save() } }, cancel: { dismiss() })
            .interactiveDismissDisabled(false)
        }
        .presentationDetents([.large])
        .orbitEditorSurface()
    }

    // MARK: - Draft values

    private var startString: String {
        startStringFrom(hour: draftStartHour, minute: draftStartMinute)
    }

    private func startStringFrom(hour: Int, minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }

    private var durationWheelTotal: Int {
        draftDurationHours * 60 + draftDurationMinutes
    }

    /// Whether the wheel combination is a writable duration (5...1440).
    /// The core stays the final validation on Save; this only disables the
    /// button for drafts the rule can never accept (00 ч 00, 24 ч 05 ...).
    private var durationWheelValid: Bool {
        TaskTimeInterval.isWritableDuration(durationWheelTotal)
    }

    /// Whether the exact stored duration cannot be represented on the
    /// 5-minute wheel (1...4, 6, 7, 61 ... — anything not a multiple of 5).
    private var savedDurationOffGrid: Bool {
        guard let saved = task.durationMinutes else { return false }
        return saved % 5 != 0
    }

    /// The duration the draft currently represents: the exact legacy value
    /// until the user explicitly moves a duration wheel, otherwise the wheel
    /// combination.
    private var effectiveDuration: Int? {
        if savedDurationOffGrid, !durationWheelActive, let legacyDurationMinutes {
            return legacyDurationMinutes
        }
        return durationWheelTotal
    }

    private var durationSummaryText: String {
        if savedDurationOffGrid, !durationWheelActive, let legacyDurationMinutes {
            return "\(RussianDurationText.text(legacyDurationMinutes)) — сохранено"
        }
        return durationWheelValid
            ? RussianDurationText.text(durationWheelTotal)
            : "недопустимая длительность"
    }

    private var durationRangeHint: String {
        "Длительность — от \(TaskTimeInterval.minimumWritableDurationMinutes) минут до \(TaskTimeInterval.maximumDurationMinutes / 60) ч 00 мин."
    }

    private var saveEnabled: Bool {
        guard effectiveDuration != nil else { return false }
        // A legacy-unchanged draft stays save-enabled: the core rejects a new
        // write of 1...4 with the existing error until a new duration is
        // chosen. Pure wheel drafts must be within 5...1440.
        return savedDurationOffGrid && !durationWheelActive ? true : durationWheelValid
    }

    /// Read-only derived end from the accepted helper; never stored.
    private var endPreview: String? {
        guard let plannedDate = task.plannedDate,
            let total = effectiveDuration,
            let end = TaskTimeInterval.end(
                plannedDate: plannedDate,
                plannedTime: startString,
                durationMinutes: total
            )
        else { return nil }
        let crossing = end.date != plannedDate ? " (+1 день)" : ""
        return "\(end.time)\(crossing)"
    }

    /// Human-readable assigned date for the context line (Russian, view-local).
    private var dateContext: String {
        guard let plannedDate = task.plannedDate else { return "—" }
        return RussianDateCaption.label(plannedDate)
    }

    // MARK: - Actions

    private func save() {
        guard let total = effectiveDuration else { return }
        if let message = model.setPlannedInterval(plannedTime: startString, durationMinutes: total, for: task) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    private func clearInterval() {
        if let message = model.setPlannedInterval(plannedTime: nil, durationMinutes: nil, for: task) {
            errorMessage = message
        } else {
            dismiss()
        }
    }

    // MARK: - Pieces

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

/// Compact Russian duration wording shared by the summary rows and the
/// legacy note: «45 мин», «1 ч 05 мин», «24 ч 00 мин».
enum RussianDurationText {
    static func text(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) мин" }
        return "\(hours) ч \(String(format: "%02d", minutes)) мин"
    }
}
