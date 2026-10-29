import SwiftUI

struct NativeModeHeader<Switcher: View, Trailing: View>: View {
    @ScaledMetric(relativeTo: .largeTitle) private var expandedTitleHeight = 56
    @Environment(\.orbitHeaderProgress) private var progress
    @Environment(\.orbitAppearance) private var appearance
    @Environment(\.orbitWorkspaceTitle) private var workspaceTitle
    @Environment(IOSInboxModel.self) private var model
    private let title: String?
    private let scrollsWithContent: Bool
    private let switcher: Switcher
    private let trailing: Trailing
    init(title: String? = nil, switcher: Switcher, scrollsWithContent: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.title = title; self.switcher = switcher; self.trailing = trailing()
        self.scrollsWithContent = scrollsWithContent
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if model.isSelecting { OrbitTaskSelectionHeader(model: model) }
            else {
                Text(title ?? workspaceTitle).font(.largeTitle.bold())
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                    .opacity(scrollsWithContent ? 1 : max(0, 1 - progress * 2))
                    .offset(y: scrollsWithContent ? 0 : -16 * progress)
                    .frame(height: expandedTitleHeight * (scrollsWithContent ? 1 : (1 - progress)), alignment: .top)
                    .clipped()
                    .accessibilityHidden(progress > 0.5)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { trailing; Spacer(minLength: 0); switcher }
                    VStack(alignment: .leading, spacing: 4) { trailing; switcher }
                }.font(.subheadline).foregroundStyle(appearance.secondaryText)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .fixedSize(horizontal: false, vertical: true)
        .orbitHeaderSurface().zIndex(10)
        .navigationTitle(title ?? workspaceTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title ?? workspaceTitle).font(.headline).opacity(max(0, progress * 2 - 1))
                    .accessibilityHidden(progress <= 0.5)
            }
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
        .padding(.horizontal, 16).padding(.vertical, 4).orbitHeaderSurface()
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        } }
    }
}


/// Read the actual scrolling surface, not an ancestor containing several views.
/// The title follows the gesture continuously; no threshold or layout animation
/// can restart a collapse while the scroll view is still decelerating.
private struct OrbitScrollingHeader: ViewModifier {
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content.environment(\.orbitHeaderProgress, min(max(offset / 80, 0), 1))
            .onPreferenceChange(OrbitMainScrollKey.self) { offset = $0 }
    }
}
extension View {
    func orbitScrollingHeader() -> some View {
        modifier(OrbitScrollingHeader())
    }
}
struct OrbitMainScrollKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
@available(iOS 18.0, *)
private struct OrbitMainScrollObserver: ViewModifier {
    @State private var offset: CGFloat = 0
    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: CGFloat.self) {
            max(0, $0.contentOffset.y + $0.contentInsets.top)
        } action: { _, value in offset = value }
        .preference(key: OrbitMainScrollKey.self, value: offset)
    }
}
extension View {
    @ViewBuilder func orbitMainScrollObserver() -> some View {
        if #available(iOS 18.0, *) { modifier(OrbitMainScrollObserver()) } else { self }
    }

    /// Empty screens still support the same pull and title motion as a full list.
    func orbitEmptyScroll() -> some View {
        GeometryReader { geometry in
            ScrollView {
                self.frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .contentMargins(.bottom, 88, for: .scrollContent)
            .scrollBounceBehavior(.always)
            .orbitMainScrollObserver()
        }
    }
}
private struct OrbitHeaderProgressKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var orbitHeaderProgress: CGFloat {
        get { self[OrbitHeaderProgressKey.self] }
        set { self[OrbitHeaderProgressKey.self] = newValue }
    }
}
