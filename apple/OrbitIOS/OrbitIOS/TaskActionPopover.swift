import SwiftUI
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
    @State private var pendingAction: OrbitTaskAction?
    @ScaledMetric(relativeTo: .body) private var menuRowHeight = 44.0
    @ScaledMetric(relativeTo: .subheadline) private var previewHeight = 110.0

    var body: some View {
        Button {
            if model.isSelecting { model.toggleSelection(task); return }
            guard canOpen() else { return }
            if anchorsAtTap {
                // SpatialTapGesture records the actual touch point in this
                // event before presentation reads its attachment anchor.
                DispatchQueue.main.async { if canOpen() { isPresented = true } }
            } else {
                isPresented = true
            }
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
                isPresented = true
            })
            .popover(isPresented: $isPresented, attachmentAnchor: anchorsAtTap ? .point(tapAnchor) : .rect(.bounds), arrowEdge: preferredArrowEdge) {
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
                            onEditProject: { wantsProject = true; isPresented = false },
                            onEditDeadline: { wantsDeadline = true; isPresented = false },
                            onEditReminder: { wantsReminder = true; isPresented = false }
                        )
                    }
                    .buttonStyle(OrbitTaskActionStyle())
                    .padding(.bottom, 6)
                  }
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(minWidth: 0, idealWidth: previewWidth, maxWidth: previewWidth, alignment: .leading)
                .frame(height: min(availableMenuHeight, menuRowHeight * 8 + previewHeight + 20))
                .background(appearance.canvas)
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
                if selecting { isPresented = false }
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

    private func choose(_ action: OrbitTaskAction) {
        pendingAction = action
        isPresented = false
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
