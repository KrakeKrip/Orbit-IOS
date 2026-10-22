import SwiftUI
import OrbitCore

/// Compact untimed card for the Calendar Day list (user reference IMG_1218):
/// a short tinted rounded rectangle (~26pt, corner radius 7) that holds the
/// small completion circle (12–14pt, left of the title) and a single-line
/// ~15pt title. No repeated date label and no always-visible action icons —
/// date and time editing stay behind the title tap and the native context
/// menu through the existing callbacks and sheets. Height is content-derived
/// (no flexible spacers); neighbouring hit regions stay inside their own
/// rows and never overlap. Accessibility sizes grow the card with Dynamic
/// Type; the full source title always stays in the accessibility label.
struct CompactCalendarTaskRow: View {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.dynamicTypeSize) private var typeSize
    let task: OrbitTask
    let model: IOSInboxModel
    let onEditDate: () -> Void
    let onEditInterval: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let onBeginDrag: () -> NSItemProvider

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                if model.isSelecting { model.toggleSelection(task) }
                else { model.setCompleted(!task.isCompleted, for: task) }
            } label: {
                ZStack {
                    Circle()
                        .fill((model.isSelecting ? model.selectedTaskIDs.contains(task.id) : task.isCompleted) ? Color.orbitAccentFill : Color.clear)
                    Circle()
                        .strokeBorder(
                            (model.isSelecting ? model.selectedTaskIDs.contains(task.id) : task.isCompleted) ? Color.orbitAccent : appearance.secondaryText.opacity(0.75),
                            lineWidth: 1.25
                        )
                    if !model.isSelecting && task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                    }
                }
                .frame(width: 22, height: 22)
                // Hit cell matches the card height; it stays inside this
                // leading column and never reaches the title's area.
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                model.isSelecting ? "Выбрать задачу: \(task.title)" : (task.isCompleted ? "Снова открыть: \(task.title)" : "Отметить выполненной: \(task.title)")
            )

            TaskActionPopoverButton(model: model, task: task,
                                    range: task.plannedDate.map(RussianDateCaption.label) ?? "Без даты",
                                    previewWidth: 300, opensOnHold: false) { action in
                switch action {
                case .toggle: model.setCompleted(!task.isCompleted, for: task)
                case .date: onEditDate()
                case .interval: onEditInterval()
                case .rename: onRename()
                case .delete: onDelete()
                }
            } label: {
                HStack(spacing: 4) {
                    TaskDeadlineBadge(task: task, compact: true)
                    TaskReminderBadge(task: task, service: model.reminders, compact: true)
                    Text(task.title)
                }
                    .font(.subheadline)
                    .foregroundStyle(task.isCompleted ? appearance.secondaryText : Color.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.tail)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.trailing, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onDrag(onBeginDrag) {
                Text(task.title).font(.subheadline).lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .padding(8).background(Color.orbitAccentFill, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(InboxRowView.accessibilitySummary(task, notificationsDenied: model.reminders.status.authorization == .denied))
            .accessibilityHint("Нажмите для меню; удерживайте и перенесите на временную сетку")
            .orbitMenuFeedback()
        }
        .frame(maxWidth: .infinity)
        .allowsHitTesting(!model.isSelecting)
        .accessibilityHidden(model.isSelecting)
        .overlay {
            if model.isSelecting {
                Button { model.toggleSelection(task) } label: {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Выбрать задачу: \(task.title)")
                .accessibilityAddTraits(model.selectedTaskIDs.contains(task.id) ? [.isSelected] : [])
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8).fill(
                task.isCompleted ? Color(.tertiarySystemFill) : appearance.surface
            )
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(model.isSelecting && model.selectedTaskIDs.contains(task.id) ? Color.orbitAccent : .clear, lineWidth: 2))
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 8))
    }

}
