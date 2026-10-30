import SwiftUI
import UIKit

struct NativeModeHeader<Switcher: View, Trailing: View>: View {
    @ScaledMetric(relativeTo: .largeTitle) private var expandedTitleHeight = 56
    @Environment(\.orbitHeaderProgress) private var progress
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
                Text(title ?? workspaceTitle).font(.largeTitle.bold())
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 12)
                    .scaleEffect(1 - 0.12 * progress, anchor: .leading)
                    .opacity(max(0, 1 - progress * 2))
                    .offset(y: -16 * progress)
                    .frame(height: expandedTitleHeight * (1 - progress), alignment: .top)
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
    @State private var scrollHandle = OrbitHeaderScrollHandle()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.background(OrbitHeaderScrollProbe(handle: scrollHandle).allowsHitTesting(false))
        .onScrollPhaseChange { old, phase in
            // Settle only a real touch/deceleration. Programmatic navigation,
            // agenda jumps and timeline auto-scroll must keep their targets.
            guard phase == .idle, old == .interacting || old == .decelerating || old == .tracking else { return }
            DispatchQueue.main.async { scrollHandle.settleHeader(animated: !reduceMotion) }
        }
        .onScrollGeometryChange(for: CGFloat.self) {
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
/// Uses the existing scroll view without replacing its delegate or gestures.
/// This also handles List, which does not implement ScrollTargetBehavior.
@MainActor
private final class OrbitHeaderScrollHandle {
    weak var scroll: UIScrollView?

    func settleHeader(animated: Bool) {
        guard let scroll, scroll.isScrollEnabled, !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { return }
        let inset = scroll.adjustedContentInset.top
        let offset = scroll.contentOffset.y + inset
        guard offset > 0.5, offset < 79.5 else { return }
        let maximum = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom + inset)
        // If a very short list cannot reach the closed state, settle open
        // instead of clamping to another half-collapsed position.
        let target: CGFloat = offset < 40 || maximum < 80 ? 0 : 80
        scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target - inset), animated: animated)
    }
}

/// The marker is the background of the actual List/ScrollView, so match its
/// viewport in the nearest shared ancestor. No window-wide view lookup.
private struct OrbitHeaderScrollProbe: UIViewRepresentable {
    let handle: OrbitHeaderScrollHandle
    final class ProbeView: UIView {
        var resolve: (() -> Void)?
        override func layoutSubviews() { super.layoutSubviews(); resolve?() }
        override func didMoveToWindow() { super.didMoveToWindow(); resolve?() }
    }
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) {
        view.resolve = { [weak view, weak handle] in
            DispatchQueue.main.async { [weak view, weak handle] in
                guard let view, let handle, view.window != nil else { return }
                if let scroll = handle.scroll, scroll.window === view.window { return }
                let frame = view.convert(view.bounds, to: nil)
                guard frame.width > 0, frame.height > 0 else { return }
                var root = view.superview
                while let candidateRoot = root {
                    if let scroll = matchingScroll(in: candidateRoot, frame: frame) {
                        handle.scroll = scroll
                        return
                    }
                    root = candidateRoot.superview
                }
            }
        }
        view.resolve?()
    }

    private func matchingScroll(in root: UIView, frame: CGRect) -> UIScrollView? {
        if let scroll = root as? UIScrollView, !scroll.isHidden {
            let rect = scroll.convert(scroll.bounds, to: nil)
            // SwiftUI may extend the native scroll view behind navigation
            // and tab bars while the background marker stays in the safe area.
            if abs(rect.minX - frame.minX) < 2, abs(rect.width - frame.width) < 2,
               rect.minY <= frame.minY + 2,
               frame.minY - rect.minY <= scroll.adjustedContentInset.top + scroll.safeAreaInsets.top + 2,
               rect.maxY >= frame.maxY - 2,
               rect.maxY - frame.maxY <= scroll.adjustedContentInset.bottom + scroll.safeAreaInsets.bottom + 2 { return scroll }
        }
        for child in root.subviews {
            if let result = matchingScroll(in: child, frame: frame) { return result }
        }
        return nil
    }
}

private struct OrbitHeaderProgressKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var orbitHeaderProgress: CGFloat {
        get { self[OrbitHeaderProgressKey.self] }
        set { self[OrbitHeaderProgressKey.self] = newValue }
    }
}
