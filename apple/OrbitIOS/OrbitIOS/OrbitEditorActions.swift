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
