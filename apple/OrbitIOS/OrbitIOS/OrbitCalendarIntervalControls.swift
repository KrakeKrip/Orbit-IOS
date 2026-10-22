import SwiftUI

/// Bubbles calendar edit mode to the host's shared floating add button.
struct OrbitCalendarEditingKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

/// A readable alternative to overlapping resize targets on short/narrow events.
/// Appears after the hold finishes, so it never changes the viewport mid-drag.
struct OrbitCalendarIntervalControls: View {
    @Environment(\.orbitAppearance) private var appearance
    let title: String
    let onEdit: () -> Void
    let onClose: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.caption).foregroundStyle(appearance.secondaryText).lineLimit(2)
                    Label("Изменить время", systemImage: "clock").font(.subheadline.weight(.medium))
                }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain).foregroundStyle(Color.orbitAccent)
                .accessibilityLabel("Изменить время: " + title)
                .accessibilityIdentifier("calendar-edit-interval")
            Button(action: onClose) {
                Image(systemName: "xmark").font(.body.weight(.medium)).frame(width: 44, height: 44)
            }.buttonStyle(.plain).foregroundStyle(appearance.secondaryText)
                .accessibilityLabel("Закончить изменение времени")
                .accessibilityIdentifier("calendar-end-editing")
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(appearance.canvas)
        .overlay(alignment: .top) { Divider() }
    }
}
