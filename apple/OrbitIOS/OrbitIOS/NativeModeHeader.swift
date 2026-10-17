import SwiftUI

/// Shared top row: contextual content leading, view and settings controls
/// trailing. The row stays in the same safe-area position in either view.
struct NativeModeHeader<Switcher: View, Trailing: View>: View {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(IOSInboxModel.self) private var model
    private let switcher: Switcher
    private let trailing: Trailing

    init(switcher: Switcher, @ViewBuilder trailing: () -> Trailing) {
        self.switcher = switcher
        self.trailing = trailing()
    }

    var body: some View {
        Group {
            if model.isSelecting {
                OrbitTaskSelectionHeader(model: model)
            } else {
                HStack(spacing: 8) {
                    trailing
                    Spacer(minLength: 8)
                    switcher
                    OrbitSettingsButton()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(appearance.canvas)
    }
}

extension NativeModeHeader where Trailing == EmptyView {
    /// The list presentations have no trailing control on the mode row.
    init(switcher: Switcher) {
        self.init(switcher: switcher, trailing: { EmptyView() })
    }
}
