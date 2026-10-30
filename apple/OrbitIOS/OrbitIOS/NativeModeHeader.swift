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
                    .frame(height: expandedTitleHeight, alignment: .top)
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
        .orbitHeaderSurface(extendsToTop: true).zIndex(10)
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
            .environment(\.orbitHeaderPullDown, max(0, -offset))
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
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if abs(next) > abs(value) { value = next }
    }
}
private struct OrbitHeaderScrollSample: Equatable {
    let y: CGFloat
    let top: CGFloat
    let valid: Bool
}
@available(iOS 18.0, *)
private struct OrbitMainScrollObserver: ViewModifier {
    var followsCalendarGesture = false
    @State private var offset: CGFloat = 0
    @State private var scrollHandle = OrbitHeaderScrollHandle()
    @State private var referenceTopInset: CGFloat?
    @State private var followsTouch = false
    @State private var calendarPanOrigin: CGFloat?
    @State private var calendarHeaderOrigin: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    func body(content: Content) -> some View {
        content.background(OrbitHeaderScrollProbe(handle: scrollHandle).allowsHitTesting(false))
        .onScrollPhaseChange { old, phase in
            if followsCalendarGesture {
                if (phase == .tracking || phase == .interacting),
                   old != .tracking && old != .interacting {
                    calendarPanOrigin = scrollHandle.panTranslation
                    calendarHeaderOrigin = offset
                }
                followsTouch = phase == .tracking || phase == .interacting
            } else {
                followsTouch = phase == .tracking || phase == .interacting || phase == .decelerating
            }
            // A resting/programmatic calendar offset is never rubber-banding.
            // Clear the visual pull even if UIKit emits no final geometry sample.
            if !followsTouch, offset < 0 {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { offset = 0 }
            }
            // Settle only a real touch/deceleration. Programmatic navigation,
            // agenda jumps and timeline auto-scroll must keep their targets.
            guard phase == .idle, old == .interacting || old == .decelerating || old == .tracking else { return }
            if followsCalendarGesture {
                // The timeline may start at any hour. Settle only the header;
                // never move the calendar to an absolute content offset.
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    offset = offset < 40 ? 0 : 80
                }
            } else {
                DispatchQueue.main.async { scrollHandle.settleHeader(animated: !reduceMotion) }
            }
        }
        .onScrollGeometryChange(for: OrbitHeaderScrollSample.self) {
            OrbitHeaderScrollSample(y: $0.contentOffset.y, top: $0.contentInsets.top,
                                    valid: $0.containerSize.height > 0)
        } action: { old, value in
            guard value.valid else { return }
            if followsCalendarGesture {
                guard followsTouch, let translation = scrollHandle.panTranslation else { return }
                if calendarPanOrigin == nil {
                    calendarPanOrigin = translation
                    calendarHeaderOrigin = offset
                }
                // A finger's translation is independent of content insets and
                // the header's layout. Never accumulate geometry deltas here:
                // bottom bounce/layout corrections otherwise feed back into
                // header progress and can keep the main thread updating forever.
                let travel = (calendarPanOrigin ?? translation) - translation
                let next = value.y + value.top <= 0.5
                    ? 0 : min(80, max(0, calendarHeaderOrigin + travel))
                let rounded = (next * displayScale).rounded() / displayScale
                if offset != rounded { offset = rounded }
                return
            }
            // Capture the resting origin while the first native layout settles.
            // Afterwards inset-only changes are paint feedback, not finger motion.
            if referenceTopInset == nil || (offset == 0 && abs(value.y + value.top) < 0.01) {
                referenceTopInset = value.top
                scrollHandle.referenceTopInset = value.top
            }
            guard old.y != value.y || !old.valid else { return }
            let logical = value.y + (referenceTopInset ?? value.top)
            // Use the current native boundary for elastic pull, not the cached
            // collapse origin: calendar layout/navigation can change its inset.
            // Only an active user scroll may move the header below its resting edge.
            let elasticPull = followsTouch ? min(80, max(0, -(value.y + value.top))) : 0
            let resolved = elasticPull > 0 ? -elasticPull : max(0, logical)
            offset = (resolved * displayScale).rounded() / displayScale
        }
        .preference(key: OrbitMainScrollKey.self, value: offset)
    }
}
extension View {
    @ViewBuilder func orbitMainScrollObserver(followsCalendarGesture: Bool = false) -> some View {
        if #available(iOS 18.0, *) { modifier(OrbitMainScrollObserver(followsCalendarGesture: followsCalendarGesture)) } else { self }
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
/// A short project index must still be able to collapse its header. List's
/// rubber band alone springs back because the rows do not fill the viewport.
@available(iOS 18.0, *)
private struct OrbitMinimumHeaderScrollRange: ViewModifier {
    @Binding var footer: CGFloat
    let enabled: Bool
    @State private var availableHeight: CGFloat?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.orbitHeaderProgress) private var progress
    @Environment(\.orbitHeaderPullDown) private var pullDown
    @ScaledMetric(relativeTo: .largeTitle) private var titleHeight = 56

    private struct Sample: Equatable {
        let viewport: CGFloat
        let content: CGFloat
        let top: CGFloat
        let bottom: CGFloat
    }
    func body(content: Content) -> some View {
        content.onScrollGeometryChange(for: Sample.self) {
            Sample(viewport: $0.containerSize.height, content: $0.contentSize.height,
                   top: $0.contentInsets.top, bottom: $0.contentInsets.bottom)
        } action: { old, value in
            guard enabled, value.viewport > 0, value.content > 0 else { return }
            // Ignore the moving header's inset feedback. Only native viewport
            // or content-size changes may alter the invisible footer.
            guard availableHeight == nil || old.viewport != value.viewport || old.content != value.content else { return }
            if availableHeight == nil || old.viewport != value.viewport {
                let restingTop = value.top + titleHeight * progress - pullDown
                availableHeight = max(0, value.viewport - restingTop - value.bottom)
            }
            guard let availableHeight else { return }
            let rows = value.content - footer
            // Two points cover native row/pixel rounding around the 80pt snap.
            let next = max(44, ((availableHeight + 82 - rows) * displayScale).rounded(.up) / displayScale)
            if abs(next - footer) > 1 / displayScale { footer = next }
        }
    }
}
extension View {
    @ViewBuilder func orbitMinimumHeaderScrollRange(footer: Binding<CGFloat>, enabled: Bool) -> some View {
        if #available(iOS 18.0, *) { modifier(OrbitMinimumHeaderScrollRange(footer: footer, enabled: enabled)) }
        else { self }
    }
}

/// Uses the existing scroll view without replacing its delegate or gestures.
/// This also handles List, which does not implement ScrollTargetBehavior.
@MainActor
private final class OrbitHeaderScrollHandle {
    weak var scroll: UIScrollView?
    var referenceTopInset: CGFloat?

    var panTranslation: CGFloat? {
        guard let scroll else { return nil }
        return scroll.panGestureRecognizer.translation(in: scroll.window).y
    }

    func settleHeader(animated: Bool) {
        guard let scroll, scroll.isScrollEnabled, !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { return }
        let inset = referenceTopInset ?? scroll.adjustedContentInset.top
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
private struct OrbitHeaderPullDownKey: EnvironmentKey { static let defaultValue: CGFloat = 0 }
extension EnvironmentValues {
    var orbitHeaderPullDown: CGFloat {
        get { self[OrbitHeaderPullDownKey.self] }
        set { self[OrbitHeaderPullDownKey.self] = newValue }
    }
    var orbitHeaderProgress: CGFloat {
        get { self[OrbitHeaderProgressKey.self] }
        set { self[OrbitHeaderProgressKey.self] = newValue }
    }
}
