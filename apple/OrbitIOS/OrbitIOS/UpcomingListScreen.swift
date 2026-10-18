import SwiftUI
import OrbitCore

/// The Upcoming list shows exactly its selected civil day. Arrow/swipe
/// navigation is owned by UpcomingWorkspaceScreen; the agenda is the
/// separate multi-day presentation. Rows share the same store and editors.
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
    var agendaMode: Binding<Bool>? = nil

    @State private var movesForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var presentation: InboxSheetPresentation?
    @State private var pickerDate: Date = TaskPlannedDate.date(
        fromCivilDateString: TaskDaySelection.currentDay()
    ) ?? Date()

    private let gregorianNoon: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()


    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // NATIVE-UI-MODE: the same leading top mode row as in the
                // calendar presentation and the Today section, directly under
                // the navigation bar — no toolbar item, no second contour.
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: agendaMode))
                dateControls
                OverdueTaskBlock(model: model)
                if let writeError = model.writeError {
                    writeErrorBanner(writeError)
                }
                ZStack {
                    Group {
                        if model.listError != nil {
                            listErrorView
                        } else if selectedTasks.isEmpty {
                            emptyView
                        } else {
                            taskList
                        }
                    }
                    .id(selectedDay)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: movesForward ? .trailing : .leading).combined(with: .opacity),
                        removal: .move(edge: movesForward ? .leading : .trailing).combined(with: .opacity)))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
                    guard !model.isSelecting, presentation == nil else { return }
                    let dx = value.translation.width
                    let dy = value.translation.height
                    // Require a deliberate horizontal stroke, not a vertical
                    // scroll with a little sideways drift; never use momentum
                    // to skip more than one day.
                    guard abs(dx) >= 70, abs(dx) > abs(dy) * 1.6,
                          let day = shiftedDay(dx < 0 ? 1 : -1) else { return }
                    select(day, animated: true)
                })
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

    private var selectedTasks: [OrbitTask] {
        TaskDaySelection.tasks(onDay: selectedDay, in: model.tasks)
    }

    private var taskList: some View {
        List {
            ForEach(selectedTasks) { task in
                InboxRowView(task: task, model: model, showsDateLabel: false) {
                    presentation = .date(task)
                } onEditInterval: {
                    presentation = .interval(task)
                }
            }
        }
        .id(selectedDay)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label("На этот день задач нет", systemImage: "calendar")
        } description: {
            Text("Выберите другой день свайпом или стрелками — либо добавьте задачу кнопкой «+».")
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
        .accessibilityValue(RussianDateCaption.label(selectedDay))
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
    private func select(_ day: String, animated: Bool = false) {
        guard TaskPlannedDate.isValid(day), day != selectedDay else { return }
        movesForward = day > selectedDay
        if animated {
            withAnimation(.easeInOut(duration: reduceMotion ? 0.12 : 0.22)) {
                selectedDay = day
            }
        } else {
            selectedDay = day
        }
    }

    /// The wheel always shows the currently selected civil day; writes of an
    /// equal date are no-ops, so syncing back from the picker never loops.
    private func syncPicker(to day: String? = nil) {
        let target = day ?? selectedDay
        pickerDate = TaskPlannedDate.date(fromCivilDateString: target, calendar: gregorianNoon) ?? pickerDate
    }
}
