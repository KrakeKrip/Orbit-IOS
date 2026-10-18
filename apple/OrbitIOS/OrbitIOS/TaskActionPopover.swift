import SwiftUI
import UIKit
import OrbitCore

enum OrbitTaskAction {
    case toggle, date, interval, rename, delete
}

/// Tap presents a card above the actions, rather than a native Menu which
/// hides its label while open. The calendar rectangle keeps its exact height.
struct TaskActionPopoverButton<Content: View>: View {
    let model: IOSInboxModel
    let task: OrbitTask
    let range: String
    let previewWidth: CGFloat
    var maximumHeight: CGFloat = 520
    var anchorsAtTap = false
    var calendarViewport: CGRect? = nil
    var opensOnHold = true
    var canOpen: () -> Bool = { true }
    let onAction: (OrbitTaskAction) -> Void
    @ViewBuilder let label: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.orbitAppearance) private var appearance
    @State private var isPresented = false
    @State private var sourceSize = CGSize(width: 1, height: 1)
    @State private var tapAnchor = UnitPoint.center
    @State private var sourceFrame: CGRect = .zero
    @State private var wantsProject = false
    @State private var showsProject = false
    @State private var wantsReminder = false
    @State private var showsReminder = false
    @State private var wantsDeadline = false
    @State private var showsDeadline = false
    @State private var measuredMenuHeight: CGFloat = 0
    @State private var pendingAction: OrbitTaskAction?
    @ScaledMetric(relativeTo: .body) private var menuRowHeight = 44.0
    @ScaledMetric(relativeTo: .subheadline) private var previewHeight = 110.0

    var body: some View {
        Button {
            if model.isSelecting { model.toggleSelection(task); return }
            guard canOpen() else { return }
            // Anchor and presentation state are consumed together on the next
            // render. Do not enqueue opening after a subsequent outside tap.
            setPresented(true)
        } label: { label() }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                sourceFrame = $0
                sourceSize = $0.size
            }
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                guard !model.isSelecting, anchorsAtTap, canOpen() else { return }
                tapAnchor = UnitPoint(
                    x: min(1, max(0, value.location.x / max(1, sourceSize.width))),
                    y: min(1, max(0, value.location.y / max(1, sourceSize.height))))
            })
            .modifier(TaskPopoverHoldModifier(enabled: opensOnHold && !model.isSelecting) {
                OrbitHaptics.longPress()
                setPresented(true)
            })
            .popover(isPresented: Binding(get: { isPresented }, set: { setPresented($0) }), attachmentAnchor: anchorsAtTap ? .point(tapAnchor) : .rect(.bounds), arrowEdge: preferredArrowEdge) {
                ScrollView {
                  VStack(spacing: 0) {
                    TaskActionPreview(task: task, range: range, reminders: model.reminders)
                        .padding(10)
                    VStack(spacing: 0) {
                        OrbitTaskMenuActions(
                            task: task,
                            onToggle: { choose(.toggle) },
                            onEditDate: { choose(.date) },
                            onEditInterval: { choose(.interval) },
                            onRename: { choose(.rename) },
                            onDelete: { choose(.delete) },
                            onEditProject: { wantsProject = true; setPresented(false) },
                            onEditDeadline: { wantsDeadline = true; setPresented(false) },
                            onEditReminder: { wantsReminder = true; setPresented(false) }
                        )
                    }
                    .buttonStyle(OrbitTaskActionStyle())
                    .padding(.bottom, 6)
                  }
                  .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { measuredMenuHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(minWidth: 0, idealWidth: previewWidth, maxWidth: previewWidth, alignment: .leading)
                .frame(height: min(availableMenuHeight, measuredMenuHeight > 0 ? measuredMenuHeight : menuRowHeight * 8 + previewHeight + 20))
                .background(appearance.canvas)
                .background(TaskMenuAppearance(reduceMotion: reduceMotion))
                .presentationBackground(appearance.canvas)
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    // Present editors/confirmation only after the popover is
                    // gone. Tapping outside leaves pendingAction nil.
                    if wantsReminder {
                        wantsReminder = false
                        showsReminder = true
                        return
                    }
                    if wantsDeadline {
                        wantsDeadline = false
                        showsDeadline = true
                        return
                    }
                    if wantsProject {
                        wantsProject = false
                        showsProject = true
                        return
                    }
                    guard let action = pendingAction else { return }
                    pendingAction = nil
                    onAction(action)
                }
            }
            .onChange(of: model.isSelecting) { _, selecting in
                if selecting { setPresented(false) }
            }
            .accessibilityAddTraits(model.isSelecting && model.selectedTaskIDs.contains(task.id) ? [.isSelected] : [])
            .sheet(isPresented: $showsReminder) { TaskReminderSheet(model: model, task: task) }
            .sheet(isPresented: $showsDeadline) { TaskDeadlineSheet(model: model, task: task) }
            .sheet(isPresented: $showsProject) { TaskProjectSheet(model: model, task: task) }
    }

    // A vertical arrow keeps the menu out of narrow side gutters. Choose
    // the half with more room and let the ScrollView fit that real space.
    private var preferredArrowEdge: Edge {
        guard anchorsAtTap, let viewport = calendarViewport else { return .top }
        return sourceFrame.minY + sourceSize.height * tapAnchor.y > viewport.midY ? .bottom : .top
    }

    private var availableMenuHeight: CGFloat {
        guard anchorsAtTap, let viewport = calendarViewport else { return maximumHeight }
        let y = min(viewport.maxY, max(viewport.minY, sourceFrame.minY + sourceSize.height * tapAnchor.y))
        let room = preferredArrowEdge == .bottom ? y - viewport.minY : viewport.maxY - y
        return min(maximumHeight, max(44, room - 24))
    }

    private func setPresented(_ presented: Bool) {
        // UIKit modal transitions otherwise ignore taps until their completion.
        // Animate its content separately, without blocking outside dismissal.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { isPresented = presented }
    }

    private func choose(_ action: OrbitTaskAction) {
        pendingAction = action
        setPresented(false)
    }
}

struct TaskActionPreview: View {
    let task: OrbitTask
    let range: String
    let reminders: OrbitReminderScheduler
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(task.title).font(.headline).lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(range).font(.subheadline.monospacedDigit())
            TaskDeadlineBadge(task: task, preview: true)
            TaskReminderBadge(task: task, service: reminders, preview: true)
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(task.isCompleted ? Color.gray : Color.orbitAccent,
                    in: RoundedRectangle(cornerRadius: 10))
        .accessibilityIdentifier("calendar-task-menu-preview")
    }
}

private struct OrbitTaskActionStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .padding(.horizontal, 16)
            .foregroundStyle(configuration.role == .destructive ? Color.red : Color.primary)
            .contentShape(Rectangle())
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : .clear)
    }
}


/// Leave calendar buttons free of the list's hold recognizer and gesture
/// mask. The calendar owns its own sequenced hold/drag recognition.
private struct TaskPopoverHoldModifier: ViewModifier {
    let enabled: Bool
    let action: () -> Void
    func body(content: Content) -> some View {
        if enabled {
            content.simultaneousGesture(LongPressGesture(minimumDuration: 0.45).onEnded { _ in action() })
        } else {
            content
        }
    }
}

/// Animate only this popover's hosted content. Unlike UIKit's modal
/// transition, this animation explicitly permits immediate interaction.
private struct TaskMenuAppearance: UIViewRepresentable {
    let reduceMotion: Bool
    func makeCoordinator() -> Coordinator { Coordinator(reduceMotion: reduceMotion) }
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.mounted = { [weak coordinator = context.coordinator] view in coordinator?.animate(view) }
        return view
    }
    func updateUIView(_ view: Probe, context: Context) {
        if view.window != nil { context.coordinator.animate(view) }
    }
    final class Probe: UIView {
        var mounted: ((UIView) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { mounted?(self) }
        }
    }
    final class Coordinator {
        let reduceMotion: Bool
        var started = false
        init(reduceMotion: Bool) { self.reduceMotion = reduceMotion }
        func animate(_ anchor: UIView) {
            guard !started else { return }
            var responder: UIResponder? = anchor
            while let current = responder {
                if let controller = current as? UIViewController {
                    started = true
                    let content = controller.view!
                    UIView.performWithoutAnimation {
                        content.alpha = 0
                        content.transform = reduceMotion ? .identity : CGAffineTransform(scaleX: 0.96, y: 0.96)
                    }
                    DispatchQueue.main.async { [weak content, reduceMotion] in
                        guard let content else { return }
                        UIView.animate(withDuration: reduceMotion ? 0.1 : 0.18, delay: 0,
                                       options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseOut]) {
                            content.alpha = 1
                            content.transform = .identity
                        }
                    }
                    return
                }
                responder = current.next
            }
        }
    }
}
