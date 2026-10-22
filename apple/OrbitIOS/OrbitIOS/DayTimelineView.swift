import SwiftUI
import Combine
import UniformTypeIdentifiers
import OrbitCore

/// Civil day timeline: tap for actions, hold-and-drag to move, handles to resize.
/// A gesture edits only a local frozen draft; one validated write on release.
struct DayTimelineView: View {
    @Environment(\.scenePhase) private var phase
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: IOSInboxModel
    let day: String
    @Binding var untimedDrag: UntimedCalendarDrag?
    let onCommitUntimed: (UntimedCalendarDrag, TaskTimelineAdjustment.Candidate) -> String?
    let onReturnHover: (CGPoint?) -> Bool
    let onReturnUntimed: (OrbitTask) -> String?
    let creationSheetPresented: Bool
    let onCreateInterval: (String, Int) -> Void
    let segments: [TaskDayIntervalSegment]
    /// Resolves a projected task UUID to the live shared-model task object.
    let task: (UUID) -> OrbitTask?
    let onEditInterval: (OrbitTask) -> Void
    let onComplete: (OrbitTask) -> Void
    let onReopen: (OrbitTask) -> Void
    let onEditDate: (OrbitTask) -> Void
    let onRename: (OrbitTask) -> Void
    let onDelete: (OrbitTask) -> Void
    let onCommitInterval: (OrbitTask, String, Int) -> String?
    @State private var creationDraft: TaskTimelineCreation.Candidate?
    @State private var creationDay: String?
    @State private var scrollView: UIScrollView?
    @State private var dragPoint: CGPoint?
    @State private var dragTranslation: CGFloat = 0
    @State private var dragOriginOffset: CGFloat = 0
    @State private var creationStartMinute: Double?
    @ScaledMetric(relativeTo: .caption) private var calendarFont = 13.0
    private let edgeTicks = Timer.publish(every: 1.0 / 30, on: .main, in: .common).autoconnect()
    @State private var timelineScrollOffset: CGFloat = 0
    @State private var untimedCandidate: TaskTimelineAdjustment.Candidate?
    @State private var returningUntimed = false
    @State private var selectedTaskID: UUID?
    @State private var editing: TimelineGestureEdit?
    @State private var gestureError: String?
    @State private var lastGestureFinish = Date.distantPast
    @GestureState private var gestureActive = false

    /// Uniform linear hour height.
    private let hourHeight: CGFloat = 64
    @ScaledMetric(relativeTo: .caption) private var laneInset = 56.0
    private static let laneTrailing: CGFloat = 10
    /// Visible gutter between side-by-side lanes.
    private static let laneGutter: CGFloat = 2

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // A real hit surface covers empty spaces between hour
                        // lines too; the decorative ruler does not consume taps.
                        Rectangle().fill(appearance.canvas)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard editing == nil else { return }
                                selectedTaskID = nil
                            }
                            .accessibilityHidden(true)
                        ruler.allowsHitTesting(false)
                        blocks(containerSize: geometry.size, viewport: geometry.frame(in: .global))
                            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: displaySegments)
                        untimedPreview(containerWidth: geometry.size.width)
                        creationPreview(containerWidth: geometry.size.width)
                    }
                    .frame(width: geometry.size.width, height: 24 * hourHeight + 24)
                    .background(appearance.canvas)
                    .background(TimelineScrollResolver(resolve: { scrollView = $0 },
                        acceptsCreation: { point in
                            guard !model.isSelecting, editing == nil, untimedDrag == nil, creationDraft == nil,
                                  let scrollView else { return false }
                            let frame = scrollView.convert(scrollView.bounds, to: nil)
                            let x = point.x - frame.minX
                            let minute = Double((point.y - frame.minY + scrollView.contentOffset.y) / hourHeight * 60)
                            guard x >= laneInset, x <= geometry.size.width - Self.laneTrailing else { return false }
                            return !displaySegments.contains { minute >= Double($0.startMinute) && minute <= Double($0.endMinute) }
                        }, creation: { state, start, point in
                            switch state {
                            case .began: activateCreation(start: start)
                            case .changed: updateCreation(point: point, translation: point.y - start.y)
                            case .ended:
                                updateCreation(point: point, translation: point.y - start.y)
                                if let candidate = creationDraft, creationDay == day,
                                   phase == .active, !model.isSelecting, editing == nil {
                                    selectedTaskID = nil
                                    // Freeze the visible ghost during the modal handoff.
                                    // The host clears it only when that form closes.
                                    dragPoint = nil
                                    creationDay = nil
                                    creationStartMinute = nil
                                    onCreateInterval(candidate.time, candidate.duration)
                                } else {
                                    clearCreation()
                                }
                            case .cancelled, .failed: clearCreation()
                            default: break
                            }
                        }))
                    .coordinateSpace(name: "orbit-timeline")
                    .onGeometryChange(for: CGFloat.self) { content in
                        // Both frames use the window, not ScrollView's moving
                        // named space. Their difference is the visible offset.
                        geometry.frame(in: .global).minY - content.frame(in: .global).minY
                    } action: { offset in
                        timelineScrollOffset = offset
                    }
                }
                    .onDrop(of: [UTType.text.identifier], delegate: UntimedTimelineDropDelegate(
                        source: $untimedDrag, day: day, width: geometry.size.width, hourHeight: hourHeight,
                        viewportHeight: geometry.size.height, scrollOffset: $timelineScrollOffset,
                        acceptsSource: { source in
                            guard !model.isSelecting, editing == nil, let current = task(source.taskID) else { return false }
                            return current.plannedDate == source.day && current.plannedTime == nil &&
                                current.durationMinutes == nil && current.projectID == source.projectID &&
                                current.isCompleted == source.completed
                        }, preview: { candidate in
                            if candidate?.time != untimedCandidate?.time, candidate != nil { OrbitHaptics.timelineStep() }
                            untimedCandidate = candidate
                        }, commit: { source, candidate in
                            selectedTaskID = nil
                            gestureError = onCommitUntimed(source, candidate)
                        }, failure: {
                            untimedDrag = nil
                            gestureError = "Не удалось перенести задачу. Повторите действие."
                        }))
                .onReceive(edgeTicks) { _ in
                    autoScroll(viewport: geometry.frame(in: .global))
                }
                .contentMargins(.bottom, 88, for: .scrollContent)
                .scrollDisabled(editing != nil || creationDraft != nil)
                .overlay(alignment: .top) {
                    if let gestureError {
                        OrbitErrorMessage(gestureError)
                            .padding(10).background(appearance.canvas)
                            .onTapGesture { self.gestureError = nil }
                    }
                }
                .onAppear {
                    proxy.scrollTo("hour-8", anchor: .top)
                }
            }
        }
        .preference(key: OrbitCalendarEditingKey.self, value: selectedTaskID != nil && !model.isSelecting)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !model.isSelecting, editing == nil, let id = selectedTaskID, let selected = task(id) {
                OrbitCalendarIntervalControls(title: selected.title, onEdit: {
                    selectedTaskID = nil
                    onEditInterval(selected)
                }, onClose: { selectedTaskID = nil })
            }
        }
        .onChange(of: creationSheetPresented) { _, presented in
            if !presented { clearCreation() }
        }
        .onChange(of: day) { _, _ in creationDraft = nil; creationDay = nil; editing = nil; dragPoint = nil; selectedTaskID = nil }
        .onChange(of: gestureActive) { _, active in
            if !active {
                // Also clears drafts for recognizer cancellation, after onEnded.
                DispatchQueue.main.async { if !gestureActive { editing = nil; dragPoint = nil; returningUntimed = false; _ = onReturnHover(nil) } }
            }
        }
        .onChange(of: model.isSelecting) { _, selecting in
            if selecting { dragPoint = nil; creationDraft = nil; creationDay = nil; editing = nil; selectedTaskID = nil; untimedDrag = nil; untimedCandidate = nil }
        }
        .onChange(of: untimedDrag?.token) { _, _ in untimedCandidate = nil }
        .onChange(of: phase) { _, value in
            if value != .active {
                editing = nil; clearCreation(); selectedTaskID = nil
                untimedDrag = nil; untimedCandidate = nil; returningUntimed = false
                _ = onReturnHover(nil)
            }
        }
        .onDisappear { dragPoint = nil; scrollView = nil; creationDraft = nil; creationDay = nil; editing = nil; selectedTaskID = nil; untimedCandidate = nil; returningUntimed = false; _ = onReturnHover(nil) }
    }

    private var currentScrollDelta: CGFloat {
        (scrollView?.contentOffset.y ?? timelineScrollOffset) - dragOriginOffset
    }

    private func trackDrag(_ point: CGPoint, translation: CGFloat) {
        dragPoint = point
        dragTranslation = translation
        if !returningUntimed { update(translation + currentScrollDelta) }
    }

    private func autoScroll(viewport: CGRect) {
        guard let scrollView, let point = dragPoint,
              !model.isSelecting, !returningUntimed,
              editing != nil || creationDraft != nil,
              point.x >= viewport.minX, point.x <= viewport.maxX else { return }
        let inset = scrollView.adjustedContentInset
        let lower = -inset.top
        let upper = max(lower, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
        let next = TaskTimelineAutoScroll.offset(current: Double(scrollView.contentOffset.y),
            pointer: Double(point.y - viewport.minY), viewport: Double(viewport.height),
            minimum: Double(lower), maximum: Double(upper))
        guard abs(next - Double(scrollView.contentOffset.y)) > 0.01 else { return }
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: CGFloat(next)), animated: false)
        if editing != nil { update(dragTranslation + currentScrollDelta) }
        else if let start = creationStartMinute {
            let next = TaskTimelineCreation.candidate(date: day, startMinute: start,
                deltaMinutes: Double((dragTranslation + currentScrollDelta) / hourHeight * 60))
            if next != creationDraft { OrbitHaptics.timelineStep() }
            creationDraft = next
        }
    }

    private func clearCreation() {
        creationDraft = nil; creationDay = nil; creationStartMinute = nil; dragPoint = nil
    }

    private func activateCreation(start: CGPoint) {
        guard phase == .active, !model.isSelecting, editing == nil, untimedDrag == nil,
              creationDay == nil, let scrollView else { return }
        let frame = scrollView.convert(scrollView.bounds, to: nil)
        creationDay = day
        dragOriginOffset = scrollView.contentOffset.y
        creationStartMinute = Double((start.y - frame.minY + dragOriginOffset) / hourHeight * 60)
        OrbitHaptics.longPress()
        updateCreation(point: start, translation: 0)
    }

    private func updateCreation(point: CGPoint, translation: CGFloat) {
        guard creationDay == day else { return }
        dragPoint = point
        dragTranslation = translation
        let next = TaskTimelineCreation.candidate(date: day,
            startMinute: creationStartMinute ?? 0,
            deltaMinutes: Double((translation + currentScrollDelta) / hourHeight * 60))
        if creationDraft != next, creationDraft != nil { OrbitHaptics.timelineStep() }
        creationDraft = next
    }

    @ViewBuilder private func creationPreview(containerWidth: CGFloat) -> some View {
        if let draft = creationDraft {
            let width = max(1, containerWidth - laneInset - Self.laneTrailing)
            VStack(alignment: .leading, spacing: 2) {
                Text("Новая задача").font(.caption.weight(.semibold))
                Text("\(draft.time) · \(draft.duration) мин").font(.caption)
            }
            .foregroundStyle(appearance.eventText)
            .padding(.horizontal, 6)
            .frame(width: width, height: max(5, CGFloat(draft.duration) / 60 * hourHeight), alignment: .topLeading)
            .background(appearance.eventSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.orbitAccent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .clipped()
            .position(x: laneInset + width / 2,
                      y: CGFloat(draft.startMinute) / 60 * hourHeight + CGFloat(draft.duration) / 120 * hourHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .transition(.identity)
            .transaction { $0.disablesAnimations = true }
        }
    }

    /// The source remains in «Без времени» until the validated store commit.
    /// The target is a noninteractive 30-minute ghost at its exact snapped time.
    @ViewBuilder private func untimedPreview(containerWidth: CGFloat) -> some View {
        if let source = untimedDrag, source.day == day, let candidate = untimedCandidate {
            let end = candidate.startMinute + candidate.duration
            let height = CGFloat(min(1440, end) - candidate.startMinute) / 60 * hourHeight
            VStack(alignment: .leading, spacing: 1) {
                Text(source.title).font(.caption.weight(.semibold)).lineLimit(1)
                Text("\(candidate.time)–\(clockString(end % 1440))\(end >= 1440 ? " (+1 день)" : "")")
                    .font(.caption.monospacedDigit()).lineLimit(1)
            }
            .foregroundStyle(appearance.eventText)
            .padding(.horizontal, 6)
            .frame(width: max(1, containerWidth - laneInset - Self.laneTrailing), height: height, alignment: .topLeading)
            .background(appearance.eventSurface, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.orbitAccent, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .clipped()
            .position(x: laneInset + (containerWidth - laneInset - Self.laneTrailing) / 2,
                      y: CGFloat(candidate.startMinute) / 60 * hourHeight + height / 2)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - Hour ruler

    private var ruler: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(appearance.secondaryText)
                        .lineLimit(1)

                        .frame(width: laneInset - 12, alignment: .leading)
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 1)
                    Spacer(minLength: 0)
                }
                .frame(height: hourHeight, alignment: .top)
                .id("hour-\(hour)")
            }
            // 24:00 end boundary: a label on the closing line, not a 25th hour.
            HStack(spacing: 8) {
                Text("24:00")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(appearance.secondaryText)
                    .lineLimit(1)

                    .frame(width: laneInset - 12, alignment: .leading)
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
            .frame(height: 12, alignment: .top)
        }
        .padding(.leading, 8)
    }

    // MARK: - Blocks

    private func blocks(containerSize: CGSize, viewport: CGRect) -> some View {
        let layout = laneLayout(for: displaySegments)
        return ForEach(layout, id: \.segment.taskID) { item in
            if let task = task(item.segment.taskID) {
                timelineBlock(
                    for: item.segment,
                    task: task,
                    laneIndex: item.lane,
                    laneCount: item.laneCount,
                    containerWidth: containerSize.width,
                    menuHeight: max(140, min(520, containerSize.height - 24)),
                    menuViewport: viewport
                )
            }
        }
    }

    private func timelineBlock(
        for segment: TimelineSegment,
        task: OrbitTask,
        laneIndex: Int,
        laneCount: Int,
        containerWidth: CGFloat,
        menuHeight: CGFloat,
        menuViewport: CGRect
    ) -> some View {
        let startOffset = CGFloat(segment.startMinute) / 60 * hourHeight
        // Exact painted geometry: one minute is 1.0667pt at 64pt/hour — no
        // floor, no stretch. The compact menu above is the accessible path
        // to tiny stripes.
        let paintedHeight = CGFloat(segment.endMinute - segment.startMinute) / 60 * hourHeight
        let endTimeText = segment.endMinute == 1440 ? "24:00" : clockString(segment.endMinute)
        let range = "\(clockString(segment.startMinute))–\(endTimeText)\(continuationMarkers(segment))"

        return TaskActionPopoverButton(model: model, task: task, range: range,
                                         previewWidth: min(300, max(160, containerWidth - 32)),
                                         maximumHeight: menuHeight,
                                         anchorsAtTap: true,
                                         calendarViewport: menuViewport,
                                         opensOnHold: false,
                                         canOpen: { editing == nil && Date.now.timeIntervalSince(lastGestureFinish) > 0.25 }) { action in
            switch action {
            case .toggle: if task.isCompleted { onReopen(task) } else { onComplete(task) }
            case .date: onEditDate(task)
            case .interval: onEditInterval(task)
            case .rename: onRename(task)
            case .delete: onDelete(task)
            }
        } label: {
            OrbitTimelineCard(title: task.title, range: range, completed: task.isCompleted,
                              height: paintedHeight, width: laneWidth(laneCount: laneCount, containerWidth: containerWidth), font: calendarFont,
                              continuesFrom: segment.continuesFromPreviousDay, continuesInto: segment.continuesIntoNextDay,
                              selected: model.isSelecting ? model.selectedTaskIDs.contains(task.id) : selectedTaskID == task.id,
                              selectionMode: model.isSelecting)
        }
        .buttonStyle(TimelineTaskButtonStyle())
        .frame(
            width: laneWidth(laneCount: laneCount, containerWidth: containerWidth),
            height: paintedHeight,
            alignment: .top
        )
        .clipped()
        .modifier(TimelineTaskHold(enabled: !model.isSelecting && untimedDrag == nil && creationDraft == nil, ignoresResizeHandles: selectedTaskID == task.id && paintedHeight >= 44 && laneWidth(laneCount: laneCount, containerWidth: containerWidth) >= 88) { state, start, point in
            switch state {
            case .began:
                begin(.move, task: task, segment: segment)
            case .changed:
                guard editing?.taskID == task.id else { return }
                returningUntimed = onReturnHover(point)
                trackDrag(point, translation: point.y - start.y)
            case .ended:
                if editing?.taskID == task.id {
                    returningUntimed = onReturnHover(point)
                    trackDrag(point, translation: point.y - start.y)
                    finish()
                }
            case .cancelled, .failed:
                if editing?.taskID == task.id {
                    editing = nil; dragPoint = nil; returningUntimed = false; _ = onReturnHover(nil)
                }
            default: break
            }
        })
        .overlay {
            if !model.isSelecting && selectedTaskID == task.id {
                RoundedRectangle(cornerRadius: 3).stroke(Color.orbitAccent, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if !model.isSelecting && selectedTaskID == task.id && paintedHeight >= 44 && laneWidth(laneCount: laneCount, containerWidth: containerWidth) >= 88 && !segment.continuesFromPreviousDay {
                resizeHandle(.start, task: task, segment: segment)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if !model.isSelecting && selectedTaskID == task.id && paintedHeight >= 44 && laneWidth(laneCount: laneCount, containerWidth: containerWidth) >= 88 && !segment.continuesIntoNextDay {
                resizeHandle(.end, task: task, segment: segment)
            }
        }
        .zIndex(selectedTaskID == task.id ? 2 : 0)
        .orbitMenuFeedback()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(InboxRowView.accessibilitySummary(task, notificationsDenied: model.reminders.status.authorization == .denied) + (segment.continuesFromPreviousDay ? ", продолжение с предыдущего дня" : "") + (segment.continuesIntoNextDay ? ", продолжается на следующий день" : ""))
        .accessibilityHint(model.isSelecting ? "Нажмите, чтобы изменить выбор задачи." : "Нажмите для меню; удерживайте для переноса и изменения границ. Короткие задачи доступны также в меню «Задачи дня».")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Изменить время") { onEditInterval(task) }
        .accessibilityAction(named: "Изменить дату") { onEditDate(task) }
        .accessibilityAddTraits(model.isSelecting && model.selectedTaskIDs.contains(task.id) ? [.isSelected] : [])
        // Position is outside the local gesture and popover source.
        .position(
            x: blockX(laneIndex: laneIndex, laneCount: laneCount, containerWidth: containerWidth)
                + laneWidth(laneCount: laneCount, containerWidth: containerWidth) / 2,
            y: startOffset + paintedHeight / 2
        )
        .transaction { transaction in
            // Keep the entire selected block (label, bounds and handles) in
            // one nonanimated transaction, including the release frame.
            if selectedTaskID == task.id || editing?.taskID == task.id {
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
        }
    }

    private func laneWidth(laneCount: Int, containerWidth: CGFloat) -> CGFloat {
        let available = containerWidth - laneInset - Self.laneTrailing
        let count = CGFloat(max(laneCount, 1))
        return max(1, (available - (count - 1) * Self.laneGutter) / count)
    }

    private func blockX(laneIndex: Int, laneCount: Int, containerWidth: CGFloat) -> CGFloat {
        laneInset + CGFloat(laneIndex) * (laneWidth(laneCount: laneCount, containerWidth: containerWidth) + Self.laneGutter)
    }

    private func clockString(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    private func continuationMarkers(_ segment: TimelineSegment) -> String {
        var markers = ""
        if segment.continuesFromPreviousDay { markers += " ↑" }
        if segment.continuesIntoNextDay { markers += " ↓" }
        return markers
    }

    private struct TimelineSegment: Equatable {
        let taskID: UUID
        let day: String
        var startMinute: Int
        var endMinute: Int
        var continuesFromPreviousDay: Bool
        var continuesIntoNextDay: Bool
        init(_ segment: TaskDayIntervalSegment) {
            taskID = segment.taskID; day = segment.day
            startMinute = segment.startMinute; endMinute = segment.endMinute
            continuesFromPreviousDay = segment.continuesFromPreviousDay
            continuesIntoNextDay = segment.continuesIntoNextDay
        }
    }

    private struct TimelineGestureEdit {
        let taskID: UUID
        let date: String
        let time: String
        let duration: Int
        let dayOffset: Int
        let edge: TaskTimelineAdjustment.Edge
        var candidate: TaskTimelineAdjustment.Candidate?
    }

    private var displaySegments: [TimelineSegment] {
        segments.map { source in
            var segment = TimelineSegment(source)
            if let edit = editing, edit.taskID == source.taskID, let candidate = edit.candidate {
                let start = candidate.startMinute + edit.dayOffset
                let end = start + candidate.duration
                segment.startMinute = max(0, min(1439, start))
                segment.endMinute = max(segment.startMinute + 1, min(1440, end))
                segment.continuesFromPreviousDay = start < 0
                segment.continuesIntoNextDay = end > 1440
            }
            return segment
        }.sorted {
            if $0.startMinute != $1.startMinute { return $0.startMinute < $1.startMinute }
            if $0.endMinute != $1.endMinute { return $0.endMinute < $1.endMinute }
            return $0.taskID.uuidString < $1.taskID.uuidString
        }
    }

    private func begin(_ edge: TaskTimelineAdjustment.Edge, task: OrbitTask, segment: TimelineSegment) {
        guard phase == .active, !model.isSelecting, editing == nil, let date = task.plannedDate,
              let time = task.plannedTime, let duration = task.durationMinutes else { return }
        selectedTaskID = task.id
        gestureError = nil
        editing = TimelineGestureEdit(taskID: task.id, date: date, time: time,
                                      duration: duration,
                                      dayOffset: segment.continuesFromPreviousDay ? -1440 : 0,
                                      edge: edge)
        dragOriginOffset = scrollView?.contentOffset.y ?? timelineScrollOffset
        OrbitHaptics.longPress()
        OrbitHaptics.prepareTimeline()
    }

    private func update(_ translation: CGFloat) {
        guard var edit = editing else { return }
        let previousTime = edit.candidate?.time ?? edit.time
        let previousDuration = edit.candidate?.duration ?? edit.duration
        if abs(translation) < 2 {
            edit.candidate = nil
        } else if let candidate = TaskTimelineAdjustment.candidate(
            date: edit.date, time: edit.time, duration: edit.duration,
            deltaMinutes: Double(translation / hourHeight * 60), edge: edit.edge) {
            let start = candidate.startMinute + edit.dayOffset
            guard start < 1440, start + candidate.duration > 0 else { return }
            edit.candidate = candidate
        }
        if (edit.candidate?.time ?? edit.time) != previousTime ||
            (edit.candidate?.duration ?? edit.duration) != previousDuration {
            OrbitHaptics.timelineStep()
        }
        editing = edit
    }

    private func finish() {
        guard let edit = editing else { return }
        // A completed hold/drag must not also open the button on release.
        // Ordinary taps never begin an edit and remain available.
        lastGestureFinish = .now
        editing = nil
        dragPoint = nil
        let returnToUntimed = returningUntimed
        returningUntimed = false
        _ = onReturnHover(nil)
        if returnToUntimed {
            guard let current = task(edit.taskID), current.plannedDate == edit.date,
                  current.plannedTime == edit.time, current.durationMinutes == edit.duration else {
                gestureError = "Задача изменилась. Повторите действие."
                return
            }
            gestureError = onReturnUntimed(current)
            selectedTaskID = nil
            if gestureError == nil { OrbitHaptics.selection() }
            return
        }
        guard let candidate = edit.candidate,
              candidate.time != edit.time || candidate.duration != edit.duration else { return }
        guard let current = task(edit.taskID), current.plannedDate == edit.date,
              current.plannedTime == edit.time, current.durationMinutes == edit.duration else {
            gestureError = "Задача изменилась. Повторите действие."
            selectedTaskID = nil
            return
        }
        gestureError = onCommitInterval(current, candidate.time, candidate.duration)
        if gestureError != nil { selectedTaskID = nil }
        else { OrbitHaptics.selection() }
    }

    private func resizeHandle(_ edge: TaskTimelineAdjustment.Edge,
                              task: OrbitTask, segment: TimelineSegment) -> some View {
        Circle().fill(.white)
            .overlay(Circle().stroke(Color.orbitAccent, lineWidth: 1.5))
            .frame(width: 12, height: 12)
            // Put the visible centre on the time boundary, retaining the
            // horizontal inset and the existing inward 44-point touch region.
            .offset(y: edge == .start ? -6 : 6)
            .frame(width: 44, height: 44, alignment: edge == .start ? .top : .bottom)
            .contentShape(Rectangle())
            .accessibilityLabel(edge == .start ? "Изменить начало" : "Изменить конец")
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($gestureActive) { _, state, _ in state = true }
                    .onChanged { value in
                        begin(edge, task: task, segment: segment)
                        trackDrag(value.location, translation: value.translation.height)
                    }
                    .onEnded { value in
                        trackDrag(value.location, translation: value.translation.height)
                        finish()
                    }
            )
    }

    // MARK: - Greedy lane layout (local, minimal)

    private struct LaidOutSegment {
        let segment: TimelineSegment
        let lane: Int
        let laneCount: Int
    }

    private func laneLayout(for segments: [TimelineSegment]) -> [LaidOutSegment] {
        var lanes: [(end: Int, cluster: Int)] = []
        var assigned: [(segment: TimelineSegment, lane: Int, cluster: Int)] = []
        var clusterEnd = -1
        var cluster = 0

        for segment in segments {
            if segment.startMinute >= clusterEnd {
                // New cluster: nothing on this day overlaps the previous burst.
                cluster += 1
                lanes = [(end: segment.endMinute, cluster: cluster)]
                assigned.append((segment, 0, cluster))
                clusterEnd = segment.endMinute
                continue
            }
            if let free = lanes.firstIndex(where: { $0.cluster == cluster && $0.end <= segment.startMinute }) {
                lanes[free].end = segment.endMinute
                assigned.append((segment, free, cluster))
            } else {
                lanes.append((end: segment.endMinute, cluster: cluster))
                assigned.append((segment, lanes.count - 1, cluster))
            }
            clusterEnd = max(clusterEnd, segment.endMinute)
        }

        let lanesPerCluster = Dictionary(grouping: assigned, by: \.cluster)
            .mapValues { Set($0.map(\.lane)).count }
        return assigned.map { item in
            LaidOutSegment(segment: item.segment, lane: item.lane, laneCount: lanesPerCluster[item.cluster] ?? 1)
        }
    }
}

/// Calendar blocks are directly manipulated shapes. Press state must not
/// transform/dim their label independently of the selection outline.
private struct TimelineTaskButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
    }
}

/// Resolve only the enclosing timeline scroll view; no global UIKit lookup.
struct TimelineScrollResolver: UIViewRepresentable {
    let resolve: (UIScrollView) -> Void
    let acceptsCreation: (CGPoint) -> Bool
    let creation: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIView(context: Context) -> UIView { UIView() }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
        let coordinator = context.coordinator
        DispatchQueue.main.async { [weak view] in
            var ancestor = view?.superview
            while let current = ancestor {
                if let scroll = current as? UIScrollView {
                    coordinator.attach(scroll)
                    resolve(scroll)
                    return
                }
                ancestor = current.superview
            }
        }
    }
    static func dismantleUIView(_ view: UIView, coordinator: Coordinator) { coordinator.detach() }
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: TimelineScrollResolver
        weak var scroll: UIScrollView?
        var start = CGPoint.zero
        lazy var hold: UILongPressGestureRecognizer = {
            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handle))
            recognizer.minimumPressDuration = 0.45
            recognizer.allowableMovement = 10
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()
        init(parent: TimelineScrollResolver) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(interrupt),
                name: UIApplication.willResignActiveNotification, object: nil)
        }
        deinit { NotificationCenter.default.removeObserver(self) }
        @objc private func interrupt() {
            // Cancel at UIKit's interruption boundary, including Control Center
            // and permission dialogs, before a later release can save a draft.
            hold.isEnabled = false
            hold.isEnabled = true
        }
        func attach(_ scroll: UIScrollView) {
            guard self.scroll !== scroll else { return }
            detach()
            self.scroll = scroll
            scroll.addGestureRecognizer(hold)
        }
        func detach() { scroll?.removeGestureRecognizer(hold); scroll = nil }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let point = touch.location(in: nil)
            guard parent.acceptsCreation(point) else { return false }
            start = point
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            parent.creation(recognizer.state, start, recognizer.location(in: nil))
        }
    }
}
