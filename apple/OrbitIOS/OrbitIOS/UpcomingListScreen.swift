import SwiftUI
import OrbitCore

/// The «Предстоящее» list (NATIVE-NAV-002): an inclusive 7-day civil window
/// from the selected day, tasks grouped by their own valid plannedDate as the
/// large existing rows. Read-only slice over the shared model — the same
/// rows, editors and sheets as Today/Inbox; creation stays in the Inbox
/// composer. Open and completed tasks both stay inside their day group in
/// within-day model order — no new list rules; undated and invalid dates are
/// never part of the window. At the 2199-12-31 upper bound the window is
/// clipped to the last valid day and the caption shows the actual range.
struct UpcomingListScreen: View {
    @Environment(\.orbitAppearance) private var appearance
    let model: IOSInboxModel
    /// The section's selected civil day — owned by `UpcomingWorkspaceScreen`.
    @Binding var selectedDay: String
    /// The section's List/Calendar mode — owned by `UpcomingWorkspaceScreen`.
    @Binding var showsCalendar: Bool
    /// The refreshed current local Gregorian day from the section owner
    /// (NATIVE-NAV-002-R1): gates the contextual «Сегодня» jump.
    let referenceDay: String

    @State private var presentation: InboxSheetPresentation?
    @State private var pickerDate: Date = TaskPlannedDate.date(
        fromCivilDateString: TaskDaySelection.currentDay()
    ) ?? Date()

    private let gregorianNoon: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    private static let windowLength = 7
    private static let rangeLowerBound = TaskPlannedDate.date(fromCivilDateString: "1900-01-01") ?? Date.distantPast
    private static let rangeUpperBound = TaskPlannedDate.date(fromCivilDateString: "2199-12-31") ?? Date.distantFuture

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // NATIVE-UI-MODE: the same leading top mode row as in the
                // calendar presentation and the Today section, directly under
                // the navigation bar — no toolbar item, no second contour.
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar))
                dateControls
                if let writeError = model.writeError {
                    writeErrorBanner(writeError)
                }
                Group {
                    if model.listError != nil {
                        listErrorView
                    } else if dayGroups.isEmpty {
                        emptyView
                    } else {
                        taskList
                    }
                }
            }
            // NATIVE-UI-MODE/R1: the same no-title/no-bar policy as the
            // calendar presentation and Today — the common mode row is the
            // deterministic top row directly under the safe area, so the
            // switcher keeps its position when the view switches.
            .toolbar(.hidden, for: .navigationBar)
            .background(appearance.canvas)
            .sheet(item: $presentation) { item in
                switch item {
                case .date(let task):
                    TaskDateSheet(task: task, model: model)
                case .interval(let task):
                    TaskIntervalSheet(task: task, model: model)
                }
            }
            .onAppear {
                // The external owner may already hold a manually selected day
                // (e.g. chosen in the calendar view); the picker follows it.
                syncPicker()
            }
            .onChange(of: selectedDay) { _, newDay in
                // Day changes from the calendar view keep the wheel in sync;
                // writes of an equal date are no-ops, so this never loops.
                syncPicker(to: newDay)
            }
        }
    }

    // MARK: - Window

    /// The window's civil days: the selected day plus the following days in
    /// ascending order, seven days long at most and clipped at 2199-12-31 —
    /// no day beyond the accepted range is ever added. Day arithmetic goes
    /// through the accepted Gregorian/noon adapters with the explicit
    /// calendar, never UTC instants or string seconds.
    private var windowDays: [String] {
        guard TaskPlannedDate.isValid(selectedDay) else { return [] }
        var days = [selectedDay]
        while days.count < Self.windowLength, let last = days.last {
            guard let anchor = TaskPlannedDate.date(fromCivilDateString: last, calendar: gregorianNoon),
                let next = gregorianNoon.date(byAdding: .day, value: 1, to: anchor)
            else { break }
            let candidate = TaskPlannedDate.civilDateString(from: next, calendar: gregorianNoon)
            guard TaskPlannedDate.isValid(candidate) else { break }
            days.append(candidate)
        }
        return days
    }

    /// Non-empty day groups in window order; every row keeps its source task
    /// (same UUID) and the within-day model order — no re-ranking, no new
    /// business rules.
    private var dayGroups: [(day: String, tasks: [OrbitTask])] {
        windowDays.compactMap { day in
            let tasks = TaskDaySelection.tasks(onDay: day, in: model.tasks)
            return tasks.isEmpty ? nil : (day, tasks)
        }
    }

    /// The actual shown range in Russian («14 окт. 2026 г. – 20 окт. 2026 г.»),
    /// including a clipped upper bound.
    private var rangeCaption: String {
        guard let first = windowDays.first, let last = windowDays.last else {
            return RussianDateCaption.label(selectedDay)
        }
        guard first != last else { return RussianDateCaption.label(first) }
        return "\(RussianDateCaption.label(first)) – \(RussianDateCaption.label(last))"
    }

    // MARK: - Content

    private var taskList: some View {
        List {
            Section {
                Text(rangeCaption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowBackground(appearance.canvas)
            }
            ForEach(dayGroups, id: \.day) { group in
                Section(RussianDateCaption.label(group.day)) {
                    ForEach(group.tasks) { task in
                        // NATIVE-LIST-001: the day-section header already
                        // shows the date — no repeated subtitle in the row.
                        InboxRowView(task: task, model: model, showsDateLabel: false) {
                            presentation = .date(task)
                        } onEditInterval: {
                            presentation = .interval(task)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Honest empty window: the message plus the actual range; the date and
    /// mode controls above stay available.
    private var emptyView: some View {
        VStack(spacing: 0) {
            Text(rangeCaption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 4)
            ContentUnavailableView {
                Label("В выбранном диапазоне задач нет", systemImage: "calendar")
            } description: {
                Text("Выберите другую дату или добавьте задачу кнопкой «+».")
            }
            Spacer(minLength: 0)
        }
    }

    private var listErrorView: some View {
        ContentUnavailableView {
            Label("Не удалось загрузить задачи", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text(model.listError ?? "")
        } actions: {
            Button("Повторить") { model.reload() }
                .buttonStyle(.borderedProminent)
                .tint(.orbitAccent)
        }
    }

    /// A failed complete/reopen (or another write) on this screen: the shared
    /// model keeps `writeError` until the next successful mutation, so the
    /// reason stays visible without masking the list or empty state.
    private func writeErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .accessibilityIdentifier("upcoming-write-error")
    }

    // MARK: - Date controls

    /// Compact date controls directly under the navigation bar. The
    /// contextual «Сегодня» jump exists only while the selection differs
    /// from the current local day and reserves no space when hidden; when
    /// present it may share the date row or, at narrow/accessibility widths,
    /// drop to its own compact row via `ViewThatFits`. «Сегодня» recomputes
    /// the current local day at tap time.
    private var dateControls: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                prevDayButton
                datePickerField
                nextDayButton
                Spacer(minLength: 0)
                if showsTodayJump {
                    todayButton
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    prevDayButton
                    datePickerField
                    nextDayButton
                }
                if showsTodayJump {
                    todayButton
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(appearance.canvas)
    }

    /// The jump is visible only away from today, compared as canonical
    /// civil-date strings through the owner's refreshed reference.
    private var showsTodayJump: Bool {
        selectedDay != referenceDay
    }

    private var prevDayButton: some View {
        Button {
            if let candidate = shiftedDay(-1) { select(candidate) }
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shiftedDay(-1) == nil)
        .accessibilityLabel("Предыдущий день")
    }

    private var nextDayButton: some View {
        Button {
            if let candidate = shiftedDay(1) { select(candidate) }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 17, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(shiftedDay(1) == nil)
        .accessibilityLabel("Следующий день")
    }

    private var datePickerField: some View {
        MarkedDatePicker(selection: $pickerDate,
                         taskDays: Set(model.tasks.compactMap(\.plannedDate)))
        .onChange(of: pickerDate) { _, newDate in
            select(TaskPlannedDate.civilDateString(from: newDate, calendar: gregorianNoon))
        }
    }

    private var todayButton: some View {
        Button("Сегодня") {
            select(TaskDaySelection.currentDay())
        }
        .buttonStyle(.bordered)
        .tint(.orbitAccent)
    }

    /// ±1 civil day anchored at noon, valid only inside 1900–2199.
    private func shiftedDay(_ delta: Int) -> String? {
        guard let anchor = TaskPlannedDate.date(
            fromCivilDateString: selectedDay,
            calendar: gregorianNoon
        ) else { return nil }
        guard let shifted = gregorianNoon.date(byAdding: .day, value: delta, to: anchor) else { return nil }
        let candidate = TaskPlannedDate.civilDateString(from: shifted, calendar: gregorianNoon)
        return TaskPlannedDate.isValid(candidate) ? candidate : nil
    }

    /// Guarded selection of the section's day; an invalid candidate never
    /// changes the state.
    private func select(_ day: String) {
        guard TaskPlannedDate.isValid(day) else { return }
        selectedDay = day
    }

    /// The wheel always shows the currently selected civil day; writes of an
    /// equal date are no-ops, so syncing back from the picker never loops.
    private func syncPicker(to day: String? = nil) {
        let target = day ?? selectedDay
        pickerDate = TaskPlannedDate.date(fromCivilDateString: target, calendar: gregorianNoon) ?? pickerDate
    }
}
