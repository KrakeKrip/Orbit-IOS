import SwiftUI
import UniformTypeIdentifiers
import OrbitCore
import OSLog

private let dragLog = Logger(subsystem: "local.orbit.ios", category: "CalendarDrag")

/// A transient, same-process drag token. No task is changed at drag start.
struct UntimedCalendarDrag: Equatable {
    let token: UUID
    let taskID: UUID
    let day: String
    let projectID: UUID?
    let completed: Bool
    let title: String

    var sourceDate: String? = nil
    var sourceTime: String? = nil
    var sourceDuration: Int? = nil
    var isOverdue = false
    var duration: Int { sourceDuration ?? 30 }

    func matches(_ task: OrbitTask) -> Bool {
        task.plannedDate == (isOverdue ? sourceDate : day) &&
        task.plannedTime == sourceTime && task.durationMinutes == sourceDuration &&
        task.projectID == projectID && task.isCompleted == completed
    }

    func provider() -> NSItemProvider {
        // Standard NSString representation is understood by the system drag
        // bridge. Only an opaque nonce leaves this view, never task contents.
        dragLog.notice("Beginning untimed token drag")
        return NSItemProvider(object: token.uuidString as NSString)
    }
}

/// The visible ScrollView is the drop target. Convert viewport coordinates
/// using the content-to-viewport offset measured in window coordinates.
/// Native drag cancellation never calls commit.
struct UntimedTimelineDropDelegate: DropDelegate {
    // Drag targets can be registered before onDrag populates the source.
    // Read the live binding even if SwiftUI retains an earlier delegate.
    @Binding var source: UntimedCalendarDrag?
    let day: String
    var targetDays: [String] = []
    var gutter: CGFloat = 56
    let width: CGFloat
    let hourHeight: CGFloat
    let viewportHeight: CGFloat
    @Binding var scrollOffset: CGFloat
    let acceptsSource: (UntimedCalendarDrag) -> Bool
    let preview: (TaskTimelineAdjustment.Candidate?) -> Void
    let commit: (UntimedCalendarDrag, TaskTimelineAdjustment.Candidate) -> Void
    let failure: () -> Void
    var previewDay: ((String, TaskTimelineAdjustment.Candidate?) -> Void)? = nil
    var commitDay: ((String, UntimedCalendarDrag, TaskTimelineAdjustment.Candidate) -> Void)? = nil

    private func dropDay(_ info: DropInfo) -> String {
        guard !targetDays.isEmpty else { return day }
        let index = max(0, min(targetDays.count - 1, Int((info.location.x - gutter) / max(1, (width - gutter) / CGFloat(targetDays.count)))))
        return targetDays[index]
    }

    func validateDrop(info: DropInfo) -> Bool {
        // Registration must not depend on state populated later by onDrag.
        // Actual acceptance and writes still require the live local nonce.
        info.hasItemsConforming(to: [UTType.text.identifier])
    }
    private func candidate(_ info: DropInfo) -> TaskTimelineAdjustment.Candidate? {
        guard let source, (targetDays.isEmpty ? source.day == day : true), acceptsSource(source), validateDrop(info: info),
              info.location.x >= gutter, info.location.x <= width - 10,
              info.location.y >= 0, info.location.y < viewportHeight else { return nil }
        let y = info.location.y + scrollOffset
        guard y >= 0, y < 24 * hourHeight else { return nil }
        let targetDay = dropDay(info)
        return TaskTimelineAdjustment.candidate(date: targetDay, time: "00:00", duration: source.duration,
            deltaMinutes: Double(y / hourHeight * 60), edge: .move)
    }
    func dropEntered(info: DropInfo) { dragLog.notice("Entered timeline drop target"); preview(candidate(info)); previewDay?(dropDay(info), candidate(info)) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let value = candidate(info)
        preview(value)
        previewDay?(dropDay(info), value)
        return DropProposal(operation: value == nil ? .cancel : .copy)
    }
    func dropExited(info: DropInfo) { preview(nil); previewDay?(dropDay(info), nil) }
    func performDrop(info: DropInfo) -> Bool {
        dragLog.notice("Received timeline drop")
        guard let source, let value = candidate(info),
              let provider = info.itemProviders(for: [UTType.text.identifier]).first else {
            preview(nil)
            return false
        }
        preview(nil)
        let targetDay = dropDay(info)
        previewDay?(targetDay, nil)
        guard provider.canLoadObject(ofClass: NSString.self) else { failure(); return false }
        provider.loadObject(ofClass: NSString.self) { object, error in
            let token = (object as? String).flatMap(UUID.init(uuidString:))
            Task { @MainActor in
                guard error == nil, token == source.token else { failure(); return }
                // Owner revalidates token, CURRENT day and live source again
                // after this asynchronous provider callback, before any write.
                if let commitDay { commitDay(targetDay, source, value) }
                else { commit(source, value) }
            }
        }
        return true
    }
}
