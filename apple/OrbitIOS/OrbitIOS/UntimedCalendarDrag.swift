import SwiftUI
import UniformTypeIdentifiers
import OrbitCore
import OSLog

private let dragLog = Logger(subsystem: "local.orbit.ios", category: "CalendarDrag")

extension UTType {
    static let orbitUntimedTask = UTType(exportedAs: "local.orbit.untimed-task", conformingTo: .data)
}

/// A transient, same-process drag token. No task is changed at drag start.
struct UntimedCalendarDrag: Codable, Equatable {
    let token: UUID
    let taskID: UUID
    let day: String
    let projectID: UUID?
    let completed: Bool
    let title: String

    func provider() -> NSItemProvider? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        dragLog.notice("Beginning same-process untimed drag")
        let provider = NSItemProvider()
        provider.registerDataRepresentation(forTypeIdentifier: UTType.orbitUntimedTask.identifier,
                                            visibility: .ownProcess) { completion in
            completion(data, nil)
            return nil
        }
        return provider
    }
}

/// Attached to the timeline CONTENT, not its viewport: DropInfo.location
/// therefore already includes the ScrollView's offset. The hour gutter is
/// not a scheduling target. Native drag cancellation never calls commit.
struct UntimedTimelineDropDelegate: DropDelegate {
    // Drag targets can be registered before onDrag populates the source.
    // Read the live binding even if SwiftUI retains an earlier delegate.
    @Binding var source: UntimedCalendarDrag?
    let day: String
    let width: CGFloat
    let hourHeight: CGFloat
    let acceptsSource: (UntimedCalendarDrag) -> Bool
    let preview: (TaskTimelineAdjustment.Candidate?) -> Void
    let commit: (UntimedCalendarDrag, TaskTimelineAdjustment.Candidate) -> Void
    let failure: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        guard let source, source.day == day, acceptsSource(source) else { return false }
        return info.hasItemsConforming(to: [UTType.orbitUntimedTask.identifier])
    }
    private func candidate(_ info: DropInfo) -> TaskTimelineAdjustment.Candidate? {
        guard validateDrop(info: info), info.location.x >= 56, info.location.x <= width - 10,
              info.location.y >= 0, info.location.y < 24 * hourHeight else { return nil }
        return TaskTimelineAdjustment.candidate(date: day, time: "00:00", duration: 30,
            deltaMinutes: Double(info.location.y / hourHeight * 60), edge: .move)
    }
    func dropEntered(info: DropInfo) { dragLog.notice("Entered timeline drop target"); preview(candidate(info)) }
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let value = candidate(info)
        preview(value)
        return DropProposal(operation: value == nil ? .cancel : .move)
    }
    func dropExited(info: DropInfo) { preview(nil) }
    func performDrop(info: DropInfo) -> Bool {
        dragLog.notice("Received timeline drop")
        guard let source, let value = candidate(info),
              let provider = info.itemProviders(for: [UTType.orbitUntimedTask.identifier]).first else {
            preview(nil)
            return false
        }
        preview(nil)
        provider.loadDataRepresentation(forTypeIdentifier: UTType.orbitUntimedTask.identifier) { data, error in
            let decoded = data.flatMap { try? JSONDecoder().decode(UntimedCalendarDrag.self, from: $0) }
            Task { @MainActor in
                guard error == nil, let decoded, decoded == source else { failure(); return }
                // Owner revalidates token, CURRENT day and live source again
                // after this asynchronous provider callback, before any write.
                commit(decoded, value)
            }
        }
        return true
    }
}
