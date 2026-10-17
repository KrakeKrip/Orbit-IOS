import SwiftUI
import OrbitCore

/// The «Календарь» day view: one selected civil day shown as a 00:00–24:00
/// timeline (via `TaskDayProjector`) with untimed compact chips listed
/// separately (user reference IMG_1210 — no large navigation title, the
/// compact date controls sit directly under the safe area, the native «⋯»
/// menu next to them holds «Задачи дня» — the timed segments of the day).
/// Read-only slice over the shared model — taps and the context menu reuse
/// the existing complete/reopen and date/interval editors for the source
/// task; NATIVE-ADD-002: creation happens through the shared «+» hosted by
/// the section workspace (Today preset in the fixed-day context, the
/// selected day in the browsing context), so this screen adds nothing itself.
/// NATIVE-NAV-001 fixed-day context (`fixedDay` non-nil, used inside
/// «Сегодня»): the shown day comes from the workspace's current local day
/// input, the date browser (Prev/Next/picker/«Сегодня») is hidden and the
/// compact «Список / Календарь» switcher replaces it. NATIVE-NAV-002
/// browsing context (`browsingDay` non-nil, used inside «Предстоящее»):
/// the shown day is owned externally and Prev/Next/picker/«Сегодня» write
/// through to the owner's binding — this screen never keeps a second
/// selection owner.
struct CalendarDayScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.orbitAppearance) private var appearance
    let model: IOSInboxModel
    var projectID: UUID? = nil
    var projectHeader: AnyView? = nil
    /// Fixed-day Today context: when non-nil the screen shows exactly this
    /// civil day and follows its changes from the current-day owner.
    var fixedDay: String? = nil
    /// Section mode switcher binding; rendered through the one common
    /// `NativeModeHeader` in both contexts — the fixed-day Today header
    /// (Today's own switcher) and the browsing header (the Upcoming
    /// section's switcher) — the same mode row the list presentations host.
    var todayMode: Binding<Bool>? = nil
    /// Browsing context (Upcoming): external owner of the shown civil day.
    /// When set, every date control writes through to this binding; the
    /// fixed-day Today context (default nil) is unchanged.
    var browsingDay: Binding<String>? = nil
    /// Browsing context (Upcoming): the refreshed current local Gregorian day
    /// from the section owner (NATIVE-NAV-002-R1); gates the contextual
    /// «Сегодня» jump. The fixed-day Today context (default nil) never gets
    /// a jump.
    var referenceDay: String? = nil
    var agendaMode: Binding<Bool>? = nil

    @State private var projectTask: OrbitTask?
    @State private var deadlineTask: OrbitTask?
    @State private var reminderTask: OrbitTask?
    @State private var presentation: InboxSheetPresentation?
    @State private var renamePresentation: TaskRenamePresentation?
    @State private var deletePresentation: TaskDeletePresentation?
    @State private var localSelectedDay: String = TaskDaySelection.currentDay()
    /// The shown civil day — the external browsing owner's value when one is
    /// provided, otherwise the local fixed-day state. One selection source
    /// per context, never two independent owners.
    private var selectedDay: String {
        browsingDay?.wrappedValue ?? localSelectedDay
    }
    @State private var pickerDate: Date = TaskPlannedDate.date(
        fromCivilDateString: TaskDaySelection.currentDay()
    ) ?? Date()
    @State private var untimedExpanded = false
    @State private var untimedFrame: CGRect = .zero
    @State private var returnHover = false
    @State private var untimedDrag: UntimedCalendarDrag?
    /// Measured height of the whole calendar content area (date controls +
    /// untimed region + timeline); the expanded untimed viewport derives from
    /// it instead of fixed screen math, so rotation and window changes adapt.
    @State private var contentHeight: CGFloat = 0
    /// Natural height of all untimed rows in the expanded region, measured
    /// after layout — keeps a short expanded list from becoming an empty area.
    @State private var expandedContentHeight: CGFloat?

    private let gregorianNoon: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    private static let rangeLowerBound = TaskPlannedDate.date(fromCivilDateString: "1900-01-01") ?? Date.distantPast
    private static let rangeUpperBound = TaskPlannedDate.date(fromCivilDateString: "2199-12-31") ?? Date.distantFuture

    private static let collapsedUntimedLimit = 3

    /// Rough height of one compact untimed card (≈26pt visual rounded
    /// rectangle) plus the 2pt group gap. Only a sizing estimate for the
    /// expanded viewport floor; real rows always render at their natural,
    /// Dynamic-Type-aware height.
    private static let estimatedCompactRowHeight: CGFloat = 28
    /// Left gutter of the untimed area, equal to the timeline's hour-ruler
    /// inset (DayTimelineView lane inset): the paired-chevrons expand toggle
    /// lives in this gutter and the card column's left edge lines up with
    /// the grid task area (user reference IMG_1218/IMG_1219).
    private static let untimedGridLeading: CGFloat = 56
    /// Reserves subtracted from the measured content height before the
    /// expanded untimed viewport may take its ~⅓ share. The date controls
    /// reserve covers the adaptive header: one 44pt row where it fits, or
    /// two rows («Сегодня» + «⋯» move down) on narrow widths. The gutter
    /// toggle adds no vertical budget — it sits beside the cards.
    private static let dayControlsReserve: CGFloat = 104
    private static let gridReserve: CGFloat = 220

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                dayControls
                if let writeError = model.writeError {
                    writeErrorBanner(writeError)
                }
                if model.listError != nil {
                    listErrorView
                } else {
                    if isFixedDayMode && isProjectionEmpty {
                        emptyProjectionCaption
                    }
                    untimedSection
                    DayTimelineView(
                        model: model,
                        day: selectedDay,
                        untimedDrag: $untimedDrag,
                        onCommitUntimed: commitUntimedDrag,
                        onReturnHover: { point in
                            let inside = point.map { untimedFrame.contains($0) } ?? false
                            if inside && !returnHover { OrbitHaptics.timelineStep() }
                            returnHover = inside
                            return inside
                        },
                        onReturnUntimed: { task in
                            model.setPlannedInterval(plannedTime: nil, durationMinutes: nil, for: task)
                        },
                        segments: projection.timedSegments,
                        task: { taskID in model.tasks.first { $0.id == taskID } },
                        onEditInterval: { task in presentation = .interval(task) },
                        onComplete: { task in model.setCompleted(true, for: task) },
                        onReopen: { task in model.setCompleted(false, for: task) },
                        onEditDate: { task in presentation = .date(task) },
                        onRename: { task in renamePresentation = TaskRenamePresentation(task: task) },
                        onDelete: { task in deletePresentation = TaskDeletePresentation(task: task) },
                        onCommitInterval: { task, time, duration in
                            model.setPlannedInterval(plannedTime: time, durationMinutes: duration, for: task)
                        }
                    )
                }
            }
            .background(appearance.canvas)
            // NATIVE-UI-MODE/R1: the previously empty (collapsible) navigation
            // bar is hidden — the common mode row is the deterministic top row
            // directly under the safe area in both contexts, matching the
            // list presentations.
            .toolbar(.hidden, for: .navigationBar)
            .background(
                // Adaptive sizing source: the real height of this content area
                // (safe areas applied), never fixed UIScreen values.
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { contentHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, height in contentHeight = height }
                }
            )
            .sheet(item: $reminderTask) { TaskReminderSheet(model: model, task: $0) }
            .sheet(item: $deadlineTask) { TaskDeadlineSheet(model: model, task: $0) }
            .sheet(item: $projectTask) { TaskProjectSheet(model: model, task: $0) }
            .sheet(item: $presentation) { item in
                switch item {
                case .date(let task):
                    TaskDateSheet(task: task, model: model)
                case .interval(let task):
                    TaskIntervalSheet(task: task, model: model)
                }
            }
            .taskManagementHost(model: model, renamePresentation: $renamePresentation,
                                deletePresentation: $deletePresentation)
            .onAppear {
                // Reactive model updates already refresh the rows; this reload
                // keeps the day view in sync after external changes. The
                // manually selected day is never reset here.
                applyFixedDay()
                model.reload()
                // Browsing context: the external owner may already hold a
                // manually selected day; the picker follows it.
                syncPicker()
            }
            .onChange(of: fixedDay) { _, _ in
                // The current-day owner moved midnight/timezone: follow it.
                applyFixedDay()
            }
            .onChange(of: selectedDay) { _, newDay in
                model.endSelection()
                // Day switch collapses the untimed area and drops its scroll
                // state; the timeline subtree keeps its identity and offset.
                // The picker follows the shown day in every context (writes
                // of the same value are no-ops, so no feedback loop).
                untimedDrag = nil
                untimedExpanded = false
                expandedContentHeight = nil
                syncPicker(to: newDay)
            }
            .onDisappear { untimedDrag = nil }
            .onChange(of: scenePhase) { _, phase in
                // System drag UI may temporarily make the scene inactive.
                // Only leaving the app invalidates an in-flight local drag.
                if phase == .background { untimedDrag = nil }
            }
            .onChange(of: projectID) { _, _ in untimedDrag = nil; model.endSelection() }
        }
    }

    private func beginUntimedDrag(_ task: OrbitTask) -> NSItemProvider {
        guard !model.isSelecting, task.plannedDate == selectedDay, task.plannedTime == nil, task.durationMinutes == nil else {
            return NSItemProvider()
        }
        let source = UntimedCalendarDrag(token: UUID(), taskID: task.id, day: selectedDay,
                                        projectID: task.projectID, completed: task.isCompleted, title: task.title)
        let provider = source.provider()
        untimedDrag = source
        OrbitHaptics.longPress()
        OrbitHaptics.prepareTimeline()
        return provider
    }

    private func commitUntimedDrag(_ source: UntimedCalendarDrag,
                                   _ candidate: TaskTimelineAdjustment.Candidate) -> String? {
        guard untimedDrag?.token == source.token else { return "Перенос отменён. Повторите действие." }
        // Consume once. A duplicate/delayed provider callback cannot save twice.
        untimedDrag = nil
        guard selectedDay == source.day, let current = task(withID: source.taskID),
              current.plannedDate == source.day, current.plannedTime == nil, current.durationMinutes == nil,
              current.projectID == source.projectID, current.isCompleted == source.completed,
              projectID == nil || current.projectID == projectID else {
            return "Задача или выбранный день изменились. Повторите перенос."
        }
        let error = model.setPlannedInterval(plannedTime: candidate.time, durationMinutes: candidate.duration, for: current)
        if error == nil { OrbitHaptics.selection() }
        return error
    }

    private var isFixedDayMode: Bool {
        fixedDay != nil
    }

    /// Fixed-day Today context: the shown day always equals the owner's
    /// current local day (invalid values never change the state).
    private func applyFixedDay() {
        guard let fixedDay, TaskPlannedDate.isValid(fixedDay) else { return }
        if localSelectedDay != fixedDay {
            localSelectedDay = fixedDay
        }
    }

    // MARK: - Projection

    private var scopedTasks: [OrbitTask] {
        guard let projectID else { return model.tasks }
        return model.tasks.filter { $0.projectID == projectID }
    }

    private var projection: TaskDayProjection {
        TaskDayProjector.project(day: selectedDay, in: scopedTasks)
    }

    /// NATIVE-ADD-002: a truly empty projection — no untimed tasks and no
    /// timed segments. A positive overnight continuation is a real segment,
    /// so a day that a previous-day task flows into is never treated as
    /// empty.
    private var isProjectionEmpty: Bool {
        projection.timedSegments.isEmpty && projection.untimedTaskIDs.isEmpty
    }

    /// The calm Today-calendar empty caption — the same words as the Today
    /// list empty state — as a compact line above the intact grid. The grid,
    /// its ruler and the shared «+» stay available; the browsing (Upcoming)
    /// context never receives this Today-specific «всё выполнено» line.
    private var emptyProjectionCaption: some View {
        VStack(spacing: 2) {
            Text("На сегодня всё")
            Text("Можно отдохнуть — или добавить новые планы.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityIdentifier("today-calendar-empty")
    }

    private func task(withID id: UUID) -> OrbitTask? {
        model.tasks.first { $0.id == id }
    }

    // MARK: - Day controls

    /// Compact header directly under the safe area. NATIVE-UI-MODE/R1: both
    /// contexts lead with the one common `NativeModeHeader` (same insets,
    /// height and band as the list presentations); each branch brings its own
    /// band so there are no nested paddings around the mode row.
    private var dayControls: some View {
        Group {
            if isFixedDayMode {
                fixedDayControls
            } else {
                browserDayControls
            }
        }
    }

    /// Fixed-day Today context header: the common mode row with the section
    /// switcher leading and the Russian current-day caption plus the existing
    /// «⋯» menu trailing — no Prev/Next/picker/«Сегодня» date browsing. At
    /// narrow widths the caption drops to its own line under the mode row
    /// (same adaptive shape as before R1).
    private var fixedDayControls: some View {
        Group {
            if let todayMode {
                ViewThatFits(in: .horizontal) {
                    NativeModeHeader(switcher: TodayModeSwitcher(showsCalendar: todayMode)) {
                        HStack(spacing: 8) {
                            Text(fixedDayCaption)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            calendarMenu
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        NativeModeHeader(switcher: TodayModeSwitcher(showsCalendar: todayMode)) {
                            calendarMenu
                        }
                        Text(fixedDayCaption)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 2)
                            .padding(.bottom, 6)
                            .background(appearance.canvas)
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Text(fixedDayCaption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    calendarMenu
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(appearance.canvas)
            }
        }
    }

    private var fixedDayCaption: String {
        RussianDateCaption.label(selectedDay)
    }

    /// NATIVE-UI-MODE/R1 browsing header: the common `NativeModeHeader` (the
    /// section switcher plus the «⋯» menu) is the mode row; the date browser
    /// below keeps its own matching band, exactly like the Upcoming list's
    /// mode row above its date controls. The contextual «Сегодня» jump exists
    /// only while the selection differs from the owner's current local day;
    /// `ViewThatFits` moves it to its own row at narrow/accessibility widths
    /// instead of stretching the content. Nothing is clipped or offset; the
    /// grid/ruler are untouched.
    private var browserDayControls: some View {
        VStack(alignment: .leading, spacing: 0) {
            browsingModeHeader
            ViewThatFits(in: .horizontal) {
                browserDateRow(includesJump: true)
                VStack(alignment: .leading, spacing: 0) {
                    browserDateRow(includesJump: false)
                    if showsTodayJump {
                        todayButton
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(appearance.canvas)
        }
    }

    /// The browsing context mode row: the same `NativeModeHeader`
    /// composition the Upcoming list hosts, with the existing «⋯» menu
    /// trailing. Standalone use without a mode binding keeps only the menu.
    private var browsingModeHeader: some View {
        Group {
            if let projectHeader {
                projectHeader
            } else if let todayMode {
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: todayMode, agendaMode: agendaMode)) {
                    calendarMenu
                }
            } else {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    calendarMenu
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(appearance.canvas)
            }
        }
    }

    private func browserDateRow(includesJump: Bool) -> some View {
        HStack(spacing: 8) {
            prevDayButton
            datePickerField
            nextDayButton
            if includesJump {
                Spacer(minLength: 0)
                if showsTodayJump {
                    todayButton
                }
            }
        }
    }

    /// The jump is visible only away from today, compared as canonical
    /// civil-date strings through the owner's refreshed reference. The
    /// fixed-day Today context has no `referenceDay` and never jumps.
    private var showsTodayJump: Bool {
        guard let referenceDay else { return false }
        return selectedDay != referenceDay
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
                         taskDays: Set(model.tasks.filter { projectID == nil || $0.projectID == projectID }.compactMap(\.plannedDate)))
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

    /// Native «⋯» menu next to the date controls. The standalone timed panel
    /// above the grid is gone; this menu is the one compact accessible path
    /// to every timed segment of the selected day («Задачи дня»), including
    /// tiny/dense stripes, through the existing editors and completion
    /// callbacks. With no timed segments it shows an honest disabled line —
    /// never a fake action.
    private var calendarMenu: some View {
        Menu {
            if projection.timedSegments.isEmpty {
                Button("Нет задач с временем") {}
                    .disabled(true)
            } else {
                Menu("Задачи дня") {
                    ForEach(projection.timedSegments, id: \.taskID) { segment in
                        if let timed = task(withID: segment.taskID) {
                            Menu(dayTaskMenuTitle(segment)) {
                                OrbitTaskMenuActions(
                                    task: timed,
                                    onToggle: { model.setCompleted(!timed.isCompleted, for: timed) },
                                    onEditDate: { presentation = .date(timed) },
                                    onEditInterval: { presentation = .interval(timed) },
                                    onRename: { renamePresentation = TaskRenamePresentation(task: timed) },
                                    onDelete: { deletePresentation = TaskDeletePresentation(task: timed) },
                                    onEditProject: { projectTask = timed },
                                    onEditDeadline: { deadlineTask = timed },
                                    onEditReminder: { reminderTask = timed }
                                )
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("Меню календаря")
        .accessibilityIdentifier("calendar-day-menu")
    }

    /// Full source title plus the selected-day range with continuation cues
    /// («↑»/«↓» at day edges) — the same data the grid block label shows.
    private func dayTaskMenuTitle(_ segment: TaskDayIntervalSegment) -> String {
        guard let timed = task(withID: segment.taskID) else { return "Задача" }
        let endTime = segment.endMinute == 1440 ? "24:00" : clockString(segment.endMinute)
        var range = "\(clockString(segment.startMinute))–\(endTime)"
        if segment.continuesFromPreviousDay { range += " ↑" }
        if segment.continuesIntoNextDay { range += " ↓" }
        return "\(timed.title) · \(range)"
    }

    private func clockString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
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

    /// Guarded selection: an invalid candidate never changes the state. In
    /// the browsing context the change is written through to the external
    /// owner; the fixed-day context keeps its local state.
    private func select(_ day: String) {
        guard TaskPlannedDate.isValid(day) else { return }
        if let browsingDay {
            browsingDay.wrappedValue = day
        } else {
            localSelectedDay = day
        }
        syncPicker(to: day)
    }

    /// The wheel always shows the currently selected civil day; writes of an
    /// equal date are no-ops, so syncing back from the picker never loops.
    private func syncPicker(to day: String? = nil) {
        let target = day ?? selectedDay
        pickerDate = TaskPlannedDate.date(fromCivilDateString: target, calendar: gregorianNoon) ?? pickerDate
    }

    // MARK: - Untimed area (compact chips, collapsible so many tasks never
    // push the grid)

    /// Default collapsed: up to 3 compact untimed cards in one tight group
    /// (2pt gaps), left edge aligned with the grid task area. The expand
    /// toggle is the small paired-chevrons button in the left gutter above
    /// the hour-ruler column (reference IMG_1219) — no standalone button
    /// row under the cards; «Ещё N» is a small secondary caption under the
    /// card group at its left edge. Toggle and caption appear only when
    /// there are more than 3 tasks. Expanding shows a bounded, independently
    /// scrollable viewport capped near ⅓ of the measured content height;
    /// expanding/collapsing never writes, never recreates the timeline, and
    /// never resets the grid scroll position.
    private var untimedSection: some View {
        let ids = projection.untimedTaskIDs
        let overLimit = ids.count > Self.collapsedUntimedLimit

        return VStack(alignment: .leading, spacing: 0) {
            if ids.isEmpty {
                Text("Без времени — нет задач")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
            } else {
                Text("Без времени")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 0) {
                    Group {
                        if overLimit {
                            untimedToggleButton(count: ids.count)
                        } else {
                            // Empty gutter placeholder: fixed zero height, so
                            // it never claims surplus vertical space at ≤3
                            // tasks (the column width stays for alignment).
                            Color.clear
                                .frame(height: 0)
                        }
                    }
                    .frame(width: Self.untimedGridLeading)

                    Group {
                        if untimedExpanded {
                            expandedUntimedRegion(ids: ids)
                        } else {
                            VStack(spacing: 2) {
                                ForEach(ids.prefix(Self.collapsedUntimedLimit), id: \.self) { id in
                                    untimedRow(id)
                                }
                            }
                        }
                    }
                    .padding(.trailing, 16)
                }

                if overLimit && !untimedExpanded {
                    Text("Ещё \(ids.count - Self.collapsedUntimedLimit)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, Self.untimedGridLeading)
                        .padding(.top, 2)
                }
            }
            Divider()
        }
        .frame(minHeight: 44)
        .background(returnHover ? Color.orbitAccent.opacity(0.18) : appearance.canvas)
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(returnHover ? Color.orbitAccent : .clear, lineWidth: 2))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { untimedFrame = $0 }
    }

    private func untimedRow(_ id: UUID) -> some View {
        Group {
            if let task = task(withID: id) {
                CompactCalendarTaskRow(task: task, model: model) {
                    presentation = .date(task)
                } onEditInterval: {
                    presentation = .interval(task)
                } onRename: {
                    renamePresentation = TaskRenamePresentation(task: task)
                } onDelete: {
                    deletePresentation = TaskDeletePresentation(task: task)
                } onBeginDrag: {
                    beginUntimedDrag(task)
                }
            }
        }
    }

    /// Bounded expanded region: every untimed chip of the day, scrolling
    /// internally only when they exceed the adaptive viewport (below).
    /// `.id(selectedDay)` gives this region alone a fresh scroll offset on a
    /// day switch; the timeline is a separate subtree and never remounts.
    private func expandedUntimedRegion(ids: [UUID]) -> some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(ids, id: \.self) { id in
                    untimedRow(id)
                }
            }
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { expandedContentHeight = proxy.size.height }
                        .onChange(of: proxy.size.height) { _, height in expandedContentHeight = height }
                }
            )
        }
        .id(selectedDay)
        .frame(height: min(expandedViewportCap, expandedContentHeight ?? expandedViewportCap))
    }

    /// Paired-chevrons expand/collapse toggle in the left gutter (reference
    /// IMG_1219): one small native button above the hour-ruler column,
    /// beside the first rows. The two chevrons are separate SF images whose
    /// directions swap with the state — collapsed upper-up/lower-down,
    /// expanded upper-down/lower-up — without whole-pair rotation (the
    /// combined `chevron.up.chevron.down` glyph is symmetric and would look
    /// unchanged). Its 44×44 hit sits fully inside the gutter column and
    /// never overlaps the card hit regions to its right; state never writes.
    private func untimedToggleButton(count: Int) -> some View {
        Button {
            untimedExpanded.toggle()
            if untimedExpanded {
                expandedContentHeight = nil
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: untimedExpanded ? "chevron.down" : "chevron.up")
                Image(systemName: untimedExpanded ? "chevron.up" : "chevron.down")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Color.orbitAccent)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("untimed-toggle")
        .accessibilityLabel(
            untimedExpanded ? "Свернуть без времени" : "Показать ещё \(count - Self.collapsedUntimedLimit) без времени"
        )
    }

    /// Expanded viewport cap from the measured content height: target ~⅓ of
    /// it, at least enough for four compact rows on a normal iPhone, never
    /// more than what remains after the date controls and the grid reserve.
    /// Small windows or large Dynamic Type show fewer rows and scroll
    /// inside the region instead of losing the grid.
    private var expandedViewportCap: CGFloat {
        let remaining = contentHeight - Self.dayControlsReserve - Self.gridReserve
        let target = max(
            CGFloat(Self.collapsedUntimedLimit + 1) * Self.estimatedCompactRowHeight,
            contentHeight / 3
        )
        return max(0, min(target, remaining))
    }

    // MARK: - Errors

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

    private func writeErrorBanner(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .accessibilityIdentifier("calendar-write-error")
    }
}

/// View-local Russian captions for the section-level civil-date labels
/// (NATIVE-NAV-002 P3 follow-up): explicit ru_RU/Gregorian formatting so the
/// visible dates are Russian regardless of device settings — «14 окт. 2026 г.»
/// instead of the system-locale «14 Oct 2026». The device locale is never
/// changed, civil values are never rewritten, and the shared `InboxRowView`
/// implementation stays untouched; invalid values come back unchanged.
enum RussianDateCaption {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static func label(_ civilDate: String) -> String {
        guard let date = TaskPlannedDate.date(fromCivilDateString: civilDate) else {
            return civilDate
        }
        return formatter.string(from: date)
    }
}
