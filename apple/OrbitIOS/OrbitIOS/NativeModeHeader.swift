import SwiftUI

struct NativeModeHeader<Switcher: View, Trailing: View>: View {
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.orbitWorkspaceTitle) private var workspaceTitle
    @Environment(IOSInboxModel.self) private var model
    private let title: String?
    private let switcher: Switcher
    private let trailing: Trailing
    init(title: String? = nil, switcher: Switcher, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.switcher = switcher; self.trailing = trailing()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isSelecting { OrbitTaskSelectionHeader(model: model) }
            else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { trailing; Spacer(minLength: 0); switcher }
                    VStack(alignment: .leading, spacing: 4) { trailing; switcher }
                }.font(.subheadline).foregroundStyle(appearance.secondaryText)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, 16).padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: true)
        .background(appearance.canvas).zIndex(10)
        .navigationTitle(title ?? workspaceTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if !model.isSelecting {
                ToolbarItem(placement: .topBarTrailing) { OrbitSettingsButton() }
            }
        }
    }
}
extension NativeModeHeader where Trailing == EmptyView {
    init(title: String? = nil, switcher: Switcher) { self.init(title: title, switcher: switcher, trailing: { EmptyView() }) }
}

/// Same order for every browsing context; the step remains a day/week/three days.
struct OrbitPeriodControls<DateField: View, Previous: View, Next: View, Today: View>: View {
    @Environment(IOSInboxModel.self) private var model
    @Environment(\.orbitAppearance) private var appearance
    let date: DateField
    let previous: Previous
    let next: Next
    let today: Today
    var body: some View {
        Group { if !model.isSelecting {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { date; Spacer(minLength: 0); today; previous; next }
            VStack(alignment: .leading, spacing: 4) {
                date
                HStack(spacing: 8) { today; Spacer(minLength: 0); previous; next }
            }
        }
        .buttonStyle(.plain).foregroundStyle(.primary)
        .padding(.horizontal, 16).padding(.vertical, 4).background(appearance.canvas)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } }
    }
}


/// Keeps the title responsive when fixed date controls sit above the scroll view.
@available(iOS 18.0, *)
private struct OrbitScrollingHeader: ViewModifier {
    var observesChild = true
    @State private var compact = false
    @ViewBuilder func body(content: Content) -> some View {
        if observesChild {
            content.navigationBarTitleDisplayMode(compact ? .inline : .large)
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top > 48
                } action: { _, value in compact = value }
        } else {
            content.navigationBarTitleDisplayMode(compact ? .inline : .large)
                .onPreferenceChange(OrbitMainScrollKey.self) { compact = $0 }
        }
    }
}
extension View {
    @ViewBuilder func orbitScrollingHeader(observesChild: Bool = true) -> some View {
        if #available(iOS 18.0, *) { modifier(OrbitScrollingHeader(observesChild: observesChild)) } else { self }
    }
}

struct OrbitMainScrollKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}
@available(iOS 18.0, *)
private struct OrbitMainScrollObserver: ViewModifier {
    @State private var compact = false
    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Bool.self) {
            $0.contentOffset.y + $0.contentInsets.top > 48
        } action: { _, value in compact = value }
        .preference(key: OrbitMainScrollKey.self, value: compact)
    }
}
extension View {
    @ViewBuilder func orbitMainScrollObserver() -> some View {
        if #available(iOS 18.0, *) { modifier(OrbitMainScrollObserver()) } else { self }
    }
}
