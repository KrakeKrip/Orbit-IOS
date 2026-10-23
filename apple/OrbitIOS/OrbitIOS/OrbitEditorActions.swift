import SwiftUI

private struct OrbitEditorActions: ViewModifier {
    let enabled: Bool
    let confirm: String
    let save: () -> Void
    let cancel: () -> Void
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Отмена", action: cancel).frame(minHeight: 44) }
            ToolbarItem(placement: .confirmationAction) {
                Button(confirm, action: save).fontWeight(.semibold).disabled(!enabled).frame(minHeight: 44)
            }
        }
    }
}
extension View {
    func orbitEditorActions(enabled: Bool = true, confirm: String = "Сохранить", save: @escaping () -> Void, cancel: @escaping () -> Void) -> some View {
        modifier(OrbitEditorActions(enabled: enabled, confirm: confirm, save: save, cancel: cancel))
    }
}

/// Keep field names and values readable when a horizontal summary is too narrow.
struct OrbitEditorSummary: View {
    let title: String
    let value: String
    let expanded: Bool
    @Environment(\.orbitAppearance) private var appearance
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                Text(title).fixedSize()
                Spacer(minLength: 8)
                Text(value).foregroundStyle(appearance.secondaryText).fixedSize()
                chevron
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    chevron
                }
                Text(value).foregroundStyle(appearance.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }
    private var chevron: some View {
        Image(systemName: expanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 13, weight: .medium)).foregroundStyle(Color.orbitAccent)
    }
}
