import SwiftUI
import Combine
import OrbitCore

/// One scroll surface and one hour scale for three consecutive civil days.
struct ThreeDayCalendarScreen: View {
    let model: IOSInboxModel
    @Binding var selectedDay: String
    @Binding var showsCalendar: Bool
    @Binding var showsAgenda: Bool
    @Environment(\.orbitThreeDayMode) private var threeDayMode
    let referenceDay: String
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitAppearance) private var appearance
    @State private var untimedExpanded = false
    @State private var anchorDay: String
    @State private var selectedTask: UUID?
    @State private var edit: Edit?
    @State private var error: String?
    @State private var editor: InboxSheetPresentation?
    @State private var rename: TaskRenamePresentation?
    @State private var deletion: TaskDeletePresentation?
    @State private var create: Create?
    @State private var creating: Create?
    @State private var creationOrigin: Double?
    @State private var scroll: UIScrollView?
    @State private var latestDrag: Pointer?
    private struct Pointer { let location: CGPoint; let translation: CGSize }
    @State private var creationPoint: CGPoint?
    @State private var creationStart: CGPoint?
    @State private var creationScrollOrigin: CGFloat = 0
    private let edgeTicks = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    @GestureState private var editingGesture = false
    @State private var lastRelease = Date.distantPast
    @ScaledMetric(relativeTo: .caption) private var calendarFont = 12.0
    @ScaledMetric(relativeTo: .subheadline) private var untimedRowHeight = 44.0
    private let hourHeight: CGFloat = 64
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var availableHeight: CGFloat = 800
    @ScaledMetric(relativeTo: .caption) private var gutter = 56.0
    private struct Create: Identifiable {
        let id = UUID()
        let day: String
        let time: String
        let duration: Int
    }
    private struct Edit {
        let taskID: UUID
        let date: String
        let time: String
        let duration: Int
        let column: Int
        let edge: TaskTimelineAdjustment.Edge
        let scrollOrigin: CGFloat
        var targetDate: String
        var candidate: TaskTimelineAdjustment.Candidate?
    }
    init(model: IOSInboxModel, selectedDay: Binding<String>, showsCalendar: Binding<Bool>,
         showsAgenda: Binding<Bool>, referenceDay: String) {
        self.model = model; _selectedDay = selectedDay; _showsCalendar = showsCalendar
        _showsAgenda = showsAgenda; self.referenceDay = referenceDay
        _anchorDay = State(initialValue: selectedDay.wrappedValue)
    }
    private var days: [String] { TaskTimelineWindow.days(starting: anchorDay) }
    private func task(_ id: UUID) -> OrbitTask? { model.tasks.first { $0.id == id } }
    private func projection(_ day: String) -> TaskDayProjection { TaskDayProjector.project(day: day, in: model.tasks) }
    private var picker: Binding<Date> {
        Binding(get: { TaskPlannedDate.date(fromCivilDateString: selectedDay) ?? .now }, set: {
            selectedDay = TaskPlannedDate.civilDateString(from: $0)
        })
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NativeModeHeader(switcher: UpcomingModeSwitcher(showsCalendar: $showsCalendar, agendaMode: $showsAgenda))
                OrbitPeriodControls(
                    date: MarkedDatePicker(selection: picker, taskDays: Set(model.tasks.compactMap(\.plannedDate))),
                    previous: Button { page(-3) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                        .disabled(TaskTimelineWindow.shift(days.first ?? anchorDay, by: -3) == nil).accessibilityLabel("Предыдущие три дня"),
                    next: Button { page(3) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                        .disabled(days.last == "2199-12-31").accessibilityLabel("Следующие три дня"),
                    today: Group { if selectedDay != referenceDay {
                        Button("Сегодня") { selectedDay = referenceDay; anchorDay = referenceDay }.frame(minHeight: 44)
                    } }
                )
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 0) {
                            Button("Читать задачи в повестке", systemImage: "list.bullet") { threeDayMode?.wrappedValue = false; showsAgenda = true; showsCalendar = false }.font(.footnote).frame(minHeight: 44)
                            OverdueTaskBlock(model: model)
                            dayHeaders
                            untimedRows
                        }.fixedSize(horizontal: false, vertical: true)
                    }.frame(height: min(190, max(100, availableHeight * 0.28)))
                } else {
                    OverdueTaskBlock(model: model)
                    dayHeaders
                    untimedRows
                }
                if let error { OrbitErrorMessage(error).padding(6) }
                timeline
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { availableHeight = $0 }
            .background(appearance.canvas)
            .environment(\.orbitCalendarActions, AnyView(Menu("Задачи выбранного дня") {
                if projection(selectedDay).timedSegments.isEmpty { Button("Нет задач с временем") {}.disabled(true) }
                ForEach(projection(selectedDay).timedSegments, id: \.taskID) { segment in
                    if let task = task(segment.taskID) {
                        Menu("\(task.title) · \(clock(segment.startMinute))–\(clock(segment.endMinute))") {
                            Button("Время и длительность…") { editor = .interval(task) }
                            Button("Дата…") { editor = .date(task) }
                            Button(task.isCompleted ? "Вернуть в работу" : "Завершить") { model.setCompleted(!task.isCompleted, for: task) }
                        }
                    }
                }
            }))
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editor) { item in
                switch item {
                case .date(let task): TaskDateSheet(task: task, model: model)
                case .interval(let task): TaskIntervalSheet(task: task, model: model)
                }
            }
            .sheet(item: $create, onDismiss: { creating = nil }) { value in
                TaskCreateSheet(model: model, datePreset: value.day, timePreset: value.time, durationPreset: value.duration)
            }
            .taskManagementHost(model: model, renamePresentation: $rename, deletePresentation: $deletion)
        }
        .onChange(of: selectedDay) { _, day in
            if !days.contains(day) { anchorDay = day }
            edit = nil; selectedTask = nil
        }
        .onChange(of: editingGesture) { _, active in
            if !active { DispatchQueue.main.async { if !editingGesture { edit = nil; latestDrag = nil } } }
        }
        .onChange(of: model.isSelecting) { _, selecting in
            if selecting { edit = nil; latestDrag = nil; selectedTask = nil; creating = nil; creationPoint = nil }
        }
        .onChange(of: phase) { _, value in
            if value != .active {
                edit = nil; latestDrag = nil; creating = nil; creationPoint = nil
                creationStart = nil; creationOrigin = nil; selectedTask = nil
            }
        }
        .onDisappear { edit = nil; latestDrag = nil; creating = nil; creationPoint = nil; scroll = nil }
    }
    private func page(_ delta: Int) {
        guard let next = TaskTimelineWindow.shift(days.first ?? anchorDay, by: delta) else { return }
        anchorDay = next; selectedDay = next; untimedExpanded = false
    }
    private var dayHeaders: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter)
            ForEach(days, id: \.self) { day in
                Button { selectedDay = day } label: {
                    VStack(spacing: 3) {
                        Text(TaskPlannedDate.date(fromCivilDateString: day)!.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "ru_RU"))))
                            .font(.caption).foregroundStyle(appearance.secondaryText)
                        Text(String(Int(day.suffix(2))!)).font(.headline)
                            .frame(minWidth: 44, minHeight: 44)
                            .foregroundStyle(day == selectedDay ? .white : .primary)
                            .background(day == selectedDay ? Color.orbitAccentFill : .clear, in: Circle())
                    }.frame(maxWidth: .infinity).padding(.vertical, 6)
                }.buttonStyle(.plain).accessibilityLabel(RussianDateCaption.label(day))
            }
        }.dynamicTypeSize(...DynamicTypeSize.accessibility1).fixedSize(horizontal: false, vertical: true)
    }
    private var untimedCount: Int { days.map { projection($0).untimedTaskIDs.count }.max() ?? 0 }
    private var untimedRows: some View {
        HStack(alignment: .top, spacing: 0) {
            Group {
                if untimedCount > 3 {
                    Button {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { untimedExpanded.toggle() }
                    } label: {
                        VStack(spacing: 6) {
                            Text("Без\nвремени").font(.caption2).foregroundStyle(appearance.secondaryText)
                            VStack(spacing: 2) {
                                Image(systemName: untimedExpanded ? "chevron.down" : "chevron.up")
                                Image(systemName: untimedExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.orbitAccent)
                        }
                        .frame(width: gutter).frame(minHeight: 76)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(untimedExpanded ? "Свернуть без времени" : "Развернуть без времени")
                } else {
                    Text("Без\nвремени").font(.caption2).foregroundStyle(appearance.secondaryText)
                        .frame(width: gutter)
                }
            }
            ForEach(days, id: \.self) { day in
                let ids = projection(day).untimedTaskIDs
                VStack(spacing: 2) {
                    if untimedExpanded && (ids.count > 7 || typeSize.isAccessibilitySize) {
                        ScrollView {
                            untimedTasks(ids)
                        }.frame(height: min(7 * untimedRowHeight + 6 * 3, availableHeight * 0.3))
                    } else {
                        untimedTasks(Array(ids.prefix(untimedExpanded ? 7 : 3)))
                    }
                    if !untimedExpanded && ids.count > 3 {
                        Text("Ещё \(ids.count - 3)").font(.caption2).foregroundStyle(appearance.secondaryText)
                    }
                }.frame(maxWidth: .infinity, alignment: .top).padding(.horizontal, 2)
            }
        }.frame(minHeight: 20, alignment: .top).padding(.bottom, 4)
    }
    private func untimedTasks(_ ids: [UUID]) -> some View {
        VStack(spacing: 3) {
            ForEach(ids, id: \.self) { id in
                if let task = task(id) {
                    actionButton(task, range: RussianDateCaption.label(task.plannedDate ?? selectedDay), viewport: nil) {
                        Text(task.title).font(.subheadline).lineLimit(typeSize.isAccessibilitySize ? nil : 2).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(minHeight: untimedRowHeight).padding(.horizontal, 4)
                            .background(appearance.surface, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
    }
    private var timeline: some View {
        GeometryReader { viewport in
            ScrollViewReader { reader in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        appearance.canvas.contentShape(Rectangle()).onTapGesture { selectedTask = nil }
                        VStack(spacing: 0) {
                            ForEach(0...24, id: \.self) { hour in
                                HStack(spacing: 2) {
                                    Text(String(format: "%02d:00", hour)).font(.caption.monospacedDigit())
                                        .foregroundStyle(appearance.secondaryText).frame(width: gutter - 2, alignment: .leading)
                                    Rectangle().fill(.quaternary).frame(height: 1)
                                }.frame(height: hour == 24 ? 20 : hourHeight, alignment: .top).id(hour)
                            }
                        }.allowsHitTesting(false)
                        ForEach(Array(days.enumerated()), id: \.element) { column, day in
                            Rectangle().fill(.quaternary).frame(width: 1, height: 24 * hourHeight)
                                .offset(x: gutter + CGFloat(column) * columnWidth(viewport.size.width))
                                .allowsHitTesting(false)
                            ForEach(TaskTimelineWindow.placements(projection(day).timedSegments), id: \.segment.taskID) { placement in
                                if let task = task(placement.segment.taskID) {
                                    block(task, placement: placement, column: column, viewport: viewport)
                                }
                            }
                        }
                        if let edit, let candidate = edit.candidate {
                            ghost(day: edit.targetDate, time: candidate.time, duration: candidate.duration,
                                  title: task(edit.taskID)?.title ?? "", width: viewport.size.width)
                        }
                        if let creating {
                            ghost(day: creating.day, time: creating.time, duration: creating.duration,
                                  title: "Новая задача", width: viewport.size.width)
                        }
                    }
                    .frame(width: viewport.size.width, height: 24 * hourHeight + 20)
                    .background(TimelineScrollResolver(resolve: { scroll = $0 }, acceptsCreation: { point in
                        guard !model.isSelecting, edit == nil, creating == nil, let scroll else { return false }
                        let frame = scroll.convert(scroll.bounds, to: nil)
                        let x = point.x - frame.minX - gutter
                        guard x >= 0, x < viewport.size.width - gutter else { return false }
                        let column = min(2, Int(x / columnWidth(viewport.size.width)))
                        let minute = (point.y - frame.minY + scroll.contentOffset.y) / hourHeight * 60
                        return !projection(days[column]).timedSegments.contains { minute >= CGFloat($0.startMinute) && minute < CGFloat($0.endMinute) }
                    }, creation: { state, start, point in
                        createGesture(state, start: start, point: point, width: viewport.size.width)
                    }))
                }
                .onReceive(edgeTicks) { _ in autoScroll(viewport: viewport) }
                .contentMargins(.bottom, 88, for: .scrollContent)
                .scrollDisabled(edit != nil || creating != nil)
                .onAppear { reader.scrollTo(8, anchor: .top) }
            }
        }
    }
    private func columnWidth(_ width: CGFloat) -> CGFloat { max(1, (width - gutter) / 3) }
    private func block(_ task: OrbitTask, placement: TaskTimelineWindow.Placement, column: Int, viewport: GeometryProxy) -> some View {
        let segment = placement.segment
        let columnWidth = columnWidth(viewport.size.width)
        let width = max(1, (columnWidth - 4) / CGFloat(placement.count))
        let height = CGFloat(segment.endMinute - segment.startMinute) / 60 * hourHeight
        return actionButton(task, range: "\(clock(segment.startMinute))–\(clock(segment.endMinute))", viewport: viewport.frame(in: .global)) {
            OrbitTimelineCard(title: task.title, range: "\(clock(segment.startMinute))–\(clock(segment.endMinute))",
                              completed: task.isCompleted, height: height, width: width, font: calendarFont,
                              continuesFrom: segment.continuesFromPreviousDay, continuesInto: segment.continuesIntoNextDay)
                .frame(width: width, height: height, alignment: .topLeading)
        }
        .modifier(TimelineTaskHold(enabled: !model.isSelecting && creating == nil, ignoresResizeHandles: selectedTask == task.id && height >= 44 && width >= 88) { state, start, point in
            switch state {
            case .began: begin(task, segment: segment, column: column, edge: .move)
            case .changed:
                guard edit?.taskID == task.id else { return }
                update(Pointer(location: point, translation: CGSize(width: point.x - start.x, height: point.y - start.y)), viewport: viewport)
            case .ended:
                if edit?.taskID == task.id {
                    update(Pointer(location: point, translation: CGSize(width: point.x - start.x, height: point.y - start.y)), viewport: viewport)
                    finish()
                }
            case .cancelled, .failed:
                if edit?.taskID == task.id { edit = nil; latestDrag = nil }
            default: break
            }
        })
        .overlay(alignment: .topTrailing) {
            if selectedTask == task.id && !model.isSelecting && height >= 44 && width >= 88 && !segment.continuesFromPreviousDay {
                handle(.start, task: task, segment: segment, column: column, viewport: viewport)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if selectedTask == task.id && !model.isSelecting && height >= 44 && width >= 88 && !segment.continuesIntoNextDay {
                handle(.end, task: task, segment: segment, column: column, viewport: viewport)
            }
        }
        .accessibilityAction(named: "Изменить время") { editor = .interval(task) }
        .accessibilityAction(named: "Изменить дату") { editor = .date(task) }
        .zIndex(selectedTask == task.id ? 3 : 1)
        .position(x: gutter + CGFloat(column) * columnWidth + 2 + (CGFloat(placement.lane) + 0.5) * width,
                  y: CGFloat(segment.startMinute) / 60 * hourHeight + height / 2)
        .accessibilityLabel(InboxRowView.accessibilitySummary(task, notificationsDenied: model.reminders.status.authorization == .denied) + (segment.continuesFromPreviousDay ? ", продолжение с предыдущего дня" : "") + (segment.continuesIntoNextDay ? ", продолжается на следующий день" : ""))
    }
    private func actionButton<Content: View>(_ task: OrbitTask, range: String, viewport: CGRect?, @ViewBuilder content: @escaping () -> Content) -> some View {
        TaskActionPopoverButton(model: model, task: task, range: range, previewWidth: 290,
            maximumHeight: 500, anchorsAtTap: viewport != nil, calendarViewport: viewport,
            opensOnHold: viewport == nil, canOpen: { edit == nil && Date.now.timeIntervalSince(lastRelease) > 0.25 }) { action in
                switch action {
                case .toggle: model.setCompleted(!task.isCompleted, for: task)
                case .date: editor = .date(task)
                case .interval: editor = .interval(task)
                case .rename: rename = TaskRenamePresentation(task: task)
                case .delete: deletion = TaskDeletePresentation(task: task)
                }
            } label: { content() }
            .buttonStyle(.plain)
    }
    private func begin(_ task: OrbitTask, segment: TaskDayIntervalSegment, column: Int, edge: TaskTimelineAdjustment.Edge) {
        guard phase == .active, !model.isSelecting, edit == nil, let date = task.plannedDate,
              let time = task.plannedTime, let duration = task.durationMinutes else { return }
        selectedTask = task.id
        error = nil
        edit = Edit(taskID: task.id, date: date, time: time, duration: duration,
                    column: column, edge: edge,
                    scrollOrigin: scroll?.contentOffset.y ?? 0, targetDate: date)
        OrbitHaptics.longPress()
    }
    private func update(_ value: DragGesture.Value, viewport: GeometryProxy) {
        update(Pointer(location: value.location, translation: value.translation), viewport: viewport)
    }
    private func update(_ value: Pointer, viewport: GeometryProxy) {
        guard var edit else { return }
        latestDrag = value
        let translation = value.translation.height + (scroll?.contentOffset.y ?? edit.scrollOrigin) - edit.scrollOrigin
        let column = min(2, max(0, Int(floor((value.location.x - viewport.frame(in: .global).minX - gutter) / columnWidth(viewport.size.width)))))
        let delta = edit.edge == .move ? column - edit.column : 0
        if delta == 0 && abs(translation) < 2 {
            edit.candidate = nil
            self.edit = edit
            return
        }
        guard let date = TaskTimelineWindow.shift(edit.date, by: delta),
              let candidate = TaskTimelineAdjustment.candidate(date: date, time: edit.time, duration: edit.duration,
                deltaMinutes: Double(translation / hourHeight * 60), edge: edit.edge) else { return }
        if edit.targetDate != date || edit.candidate != candidate { OrbitHaptics.timelineStep() }
        edit.targetDate = date; edit.candidate = candidate
        self.edit = edit
    }
    private func finish() {
        defer { edit = nil; latestDrag = nil; lastRelease = .now }
        guard let edit, let candidate = edit.candidate, let task = task(edit.taskID) else { return }
        guard task.plannedDate == edit.date, task.plannedTime == edit.time, task.durationMinutes == edit.duration else {
            error = "Задача изменилась. Повторите перенос."; return
        }
        error = model.setPlannedSchedule(date: edit.targetDate, time: candidate.time, duration: candidate.duration, for: task)
    }
    private func handle(_ edge: TaskTimelineAdjustment.Edge, task: OrbitTask, segment: TaskDayIntervalSegment,
                        column: Int, viewport: GeometryProxy) -> some View {
        Circle().fill(.white).overlay(Circle().stroke(Color.orbitAccent)).frame(width: 10, height: 10)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .accessibilityHint("Можно также изменить время через меню задачи")
            .accessibilityLabel(edge == .start ? "Изменить начало" : "Изменить конец")
            .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .updating($editingGesture) { _, state, _ in state = true }
                .onChanged { value in begin(task, segment: segment, column: column, edge: edge); update(value, viewport: viewport) }
                .onEnded { value in update(value, viewport: viewport); finish() })
    }
    private func ghost(day: String, time: String, duration: Int, title: String, width: CGFloat) -> some View {
        let start = (Int(time.prefix(2)) ?? 0) * 60 + (Int(time.suffix(2)) ?? 0)
        return ForEach(Array(days.enumerated()), id: \.element) { column, visibleDay in
            let previous = TaskTimelineWindow.shift(visibleDay, by: -1)
            let top = visibleDay == day ? start : 0
            let bottom = visibleDay == day ? min(1440, start + duration) : start + duration - 1440
            if visibleDay == day || (previous == day && bottom > 0) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: calendarFont, weight: .semibold)).lineLimit(2)
                    Text("\(time) · \(duration) мин").font(.caption.monospacedDigit())
                }.foregroundStyle(appearance.eventText).padding(3)
                    .frame(width: columnWidth(width) - 4, height: CGFloat(bottom - top) / 60 * hourHeight, alignment: .topLeading)
                    .background(appearance.eventSurface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orbitAccent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))).clipped()
                    .position(x: gutter + (CGFloat(column) + 0.5) * columnWidth(width), y: CGFloat(top + bottom) / 120 * hourHeight)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
    }
    private func createGesture(_ state: UIGestureRecognizer.State, start: CGPoint, point: CGPoint, width: CGFloat) {
        guard phase == .active, let scroll else { return }
        let frame = scroll.convert(scroll.bounds, to: nil)
        switch state {
        case .began:
            creationStart = start; creationPoint = point
            creationScrollOrigin = scroll.contentOffset.y
            let column = min(2, max(0, Int((start.x - frame.minX - gutter) / columnWidth(width))))
            creationOrigin = Double((start.y - frame.minY + scroll.contentOffset.y) / hourHeight * 60)
            if let candidate = TaskTimelineCreation.candidate(date: days[column], startMinute: creationOrigin!, deltaMinutes: 0) {
                creating = Create(day: days[column], time: candidate.time, duration: candidate.duration)
                OrbitHaptics.longPress()
            }
        case .changed:
            creationPoint = point
            if let creating, let origin = creationOrigin,
               let candidate = TaskTimelineCreation.candidate(date: creating.day, startMinute: origin,
                    deltaMinutes: Double((point.y - start.y + scroll.contentOffset.y - creationScrollOrigin) / hourHeight * 60)) {
                if candidate.duration != creating.duration { OrbitHaptics.timelineStep() }
                self.creating = Create(day: creating.day, time: candidate.time, duration: candidate.duration)
            }
        case .ended:
            createGesture(.changed, start: start, point: point, width: width)
            create = creating; creationOrigin = nil; creationPoint = nil; creationStart = nil
        case .cancelled, .failed: creating = nil; creationOrigin = nil; creationPoint = nil; creationStart = nil
        default: break
        }
    }
    private func autoScroll(viewport: GeometryProxy) {
        guard !model.isSelecting, create == nil, let scroll,
              let point = edit != nil ? latestDrag?.location : creationPoint else { return }
        let frame = viewport.frame(in: .global)
        guard point.x >= frame.minX, point.x <= frame.maxX else { return }
        let lower = -scroll.adjustedContentInset.top
        let upper = max(lower, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
        let next = TaskTimelineAutoScroll.offset(current: Double(scroll.contentOffset.y), pointer: Double(point.y - frame.minY),
            viewport: Double(frame.height), minimum: Double(lower), maximum: Double(upper))
        guard abs(next - Double(scroll.contentOffset.y)) > 0.01 else { return }
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: CGFloat(next)), animated: false)
        if let latestDrag, edit != nil { update(latestDrag, viewport: viewport) }
        else if let start = creationStart { createGesture(.changed, start: start, point: point, width: viewport.size.width) }
    }

    private func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
}
