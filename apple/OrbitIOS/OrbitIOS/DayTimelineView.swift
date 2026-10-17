import SwiftUI
import UniformTypeIdentifiers
import OrbitCore

/// Civil day timeline: tap for actions, hold-and-drag to move, handles to resize.
/// A gesture edits only a local frozen draft; one validated write on release.
struct DayTimelineView: View {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: IOSInboxModel
    let day: String
    @Binding var untimedDrag: UntimedCalendarDrag?
    let onCommitUntimed: (UntimedCalendarDrag, TaskTimelineAdjustment.Candidate) -> String?
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
    @State private var untimedCandidate: TaskTimelineAdjustment.Candidate?
    @State private var selectedTaskID: UUID?
    @State private var editing: TimelineGestureEdit?
    @State private var gestureError: String?
    @State private var lastGestureFinish = Date.distantPast
    @GestureState private var gestureActive = false

    /// Uniform linear hour height.
    private let hourHeight: CGFloat = 64
    private static let laneInset: CGFloat = 56
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
                        blocks(containerWidth: geometry.size.width)
                            .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: displaySegments)
                        untimedPreview(containerWidth: geometry.size.width)
                    }
                    .frame(width: geometry.size.width, height: 24 * hourHeight + 24)
                    .background(appearance.canvas)
                    .coordinateSpace(name: "orbit-timeline")
                    .onDrop(of: [UTType.orbitUntimedTask.identifier], delegate: UntimedTimelineDropDelegate(
                        source: untimedDrag, day: day, width: geometry.size.width, hourHeight: hourHeight,
                        acceptsSource: { source in
                            guard editing == nil, let current = task(source.taskID) else { return false }
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
                }
                .scrollDisabled(editing != nil)
                .overlay(alignment: .top) {
                    if let gestureError {
                        Text(gestureError).font(.footnote).foregroundStyle(.red)
                            .padding(10).background(appearance.canvas)
                            .onTapGesture { self.gestureError = nil }
                    }
                }
                .onAppear {
                    proxy.scrollTo("hour-8", anchor: .top)
                }
            }
        }
        .onChange(of: gestureActive) { _, active in
            if !active {
                // Also clears drafts for recognizer cancellation, after onEnded.
                DispatchQueue.main.async { if !gestureActive { editing = nil } }
            }
        }
        .onChange(of: untimedDrag?.token) { _, _ in untimedCandidate = nil }
        .onDisappear { editing = nil; selectedTaskID = nil; untimedCandidate = nil }
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
                    .font(.caption2.monospacedDigit()).lineLimit(1)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .frame(width: max(1, containerWidth - Self.laneInset - Self.laneTrailing), height: height, alignment: .topLeading)
            .background(Color.orbitAccent.opacity(0.75), in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.white, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])))
            .clipped()
            .position(x: Self.laneInset + (containerWidth - Self.laneInset - Self.laneTrailing) / 2,
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
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(width: 44, alignment: .leading)
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
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(width: 44, alignment: .leading)
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

    private func blocks(containerWidth: CGFloat) -> some View {
        let layout = laneLayout(for: displaySegments)
        return ForEach(layout, id: \.segment.taskID) { item in
            if let task = task(item.segment.taskID) {
                timelineBlock(
                    for: item.segment,
                    task: task,
                    laneIndex: item.lane,
                    laneCount: item.laneCount,
                    containerWidth: containerWidth
                )
            }
        }
    }

    private func timelineBlock(
        for segment: TimelineSegment,
        task: OrbitTask,
        laneIndex: Int,
        laneCount: Int,
        containerWidth: CGFloat
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
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(task.isCompleted ? Color(.systemGray4) : Color.orbitAccent.opacity(0.85))
                if paintedHeight >= 24 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 3) {
                            TaskDeadlineBadge(task: task, compact: true, preview: true)
                            TaskReminderBadge(task: task, service: model.reminders, compact: true, preview: true)
                            Text(task.title)
                        }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(task.isCompleted ? Color(.systemGray5) : .white)
                            .lineLimit(1)
                        Text(range)
                            .font(.caption2)
                            .foregroundStyle(task.isCompleted ? Color(.systemGray5) : .white.opacity(0.95))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                }
                if segment.continuesFromPreviousDay {
                    Image(systemName: "arrow.up.to.line")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.trailing, 3)
                }
                if segment.continuesIntoNextDay {
                    VStack {
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 3)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(
            width: laneWidth(laneCount: laneCount, containerWidth: containerWidth),
            height: paintedHeight,
            alignment: .top
        )
        .clipped()
        .simultaneousGesture(moveGesture(task: task, segment: segment))
        .overlay {
            if selectedTaskID == task.id {
                RoundedRectangle(cornerRadius: 3).stroke(.white, lineWidth: 2)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .topTrailing) {
            if selectedTaskID == task.id && !segment.continuesFromPreviousDay {
                resizeHandle(.start, task: task, segment: segment).offset(x: 8, y: -16)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if selectedTaskID == task.id && !segment.continuesIntoNextDay {
                resizeHandle(.end, task: task, segment: segment).offset(x: -8, y: 16)
            }
        }
        .zIndex(selectedTaskID == task.id ? 2 : 0)
        .transaction { if editing?.taskID == task.id { $0.animation = nil } }
        .orbitMenuFeedback()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(task.title), \(range)" + TaskDeadlineBadge.accessibilitySuffix(task) + TaskReminderBadge.accessibilitySuffix(task))
        .accessibilityHint("Нажмите для меню; удерживайте для переноса и изменения границ")
        .accessibilityAddTraits(task.isCompleted ? [.isSelected] : [])
        // Position is outside the local gesture and popover source.
        .position(
            x: blockX(laneIndex: laneIndex, laneCount: laneCount, containerWidth: containerWidth)
                + laneWidth(laneCount: laneCount, containerWidth: containerWidth) / 2,
            y: startOffset + paintedHeight / 2
        )
    }

    private func laneWidth(laneCount: Int, containerWidth: CGFloat) -> CGFloat {
        let available = containerWidth - Self.laneInset - Self.laneTrailing
        let count = CGFloat(max(laneCount, 1))
        return max(1, (available - (count - 1) * Self.laneGutter) / count)
    }

    private func blockX(laneIndex: Int, laneCount: Int, containerWidth: CGFloat) -> CGFloat {
        Self.laneInset + CGFloat(laneIndex) * (laneWidth(laneCount: laneCount, containerWidth: containerWidth) + Self.laneGutter)
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
        let directMove: Bool
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
        guard editing == nil, let date = task.plannedDate,
              let time = task.plannedTime, let duration = task.durationMinutes else { return }
        let directMove = selectedTaskID == task.id
        selectedTaskID = task.id
        gestureError = nil
        editing = TimelineGestureEdit(taskID: task.id, date: date, time: time,
                                      duration: duration,
                                      dayOffset: segment.continuesFromPreviousDay ? -1440 : 0,
                                      edge: edge, directMove: directMove)
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

    private func moveGesture(task: OrbitTask, segment: TimelineSegment) -> AnyGesture<Void> {
        if editing?.taskID == task.id ? editing?.directMove == true : selectedTaskID == task.id {
            return AnyGesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("orbit-timeline"))
                    .updating($gestureActive) { _, state, _ in state = true }
                    .onChanged { value in
                        begin(.move, task: task, segment: segment)
                        update(value.translation.height)
                    }
                    .onEnded { _ in finish() }
                    .map { _ in () }
            )
        }
        return AnyGesture(LongPressGesture(minimumDuration: 0.4, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("orbit-timeline")))
            .updating($gestureActive) { _, state, _ in state = true }
            .onChanged { value in
                switch value {
                // The first phase starts at touch-down, before the hold
                // threshold. Only the second phase may enter edit mode.
                case .second(true, let drag):
                    begin(.move, task: task, segment: segment)
                    if let drag { update(drag.translation.height) }
                default: break
                }
            }
            .onEnded { _ in finish() }
            .map { _ in () })
    }

    private func resizeHandle(_ edge: TaskTimelineAdjustment.Edge,
                              task: OrbitTask, segment: TimelineSegment) -> some View {
        Circle().fill(.white)
            .overlay(Circle().stroke(Color.orbitAccent, lineWidth: 1.5))
            .frame(width: 12, height: 12)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .accessibilityLabel(edge == .start ? "Изменить начало" : "Изменить конец")
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("orbit-timeline"))
                    .updating($gestureActive) { _, state, _ in state = true }
                    .onChanged { value in
                        begin(edge, task: task, segment: segment)
                        update(value.translation.height)
                    }
                    .onEnded { _ in finish() }
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
