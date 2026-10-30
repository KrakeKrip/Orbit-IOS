import SwiftUI
import UIKit
import Observation

struct NativeModeHeader<Switcher: View, Trailing: View>: View {
    @ScaledMetric(relativeTo: .largeTitle) private var expandedTitleHeight = 56
    @Environment(\.orbitHeaderMotion) private var motion
    private var progress: CGFloat { motion?.progress ?? 0 }
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
                    .opacity(1 - OrbitHeaderMotion.fade(progress, from: 0.12, to: 0.78))
                    .offset(y: -6 * progress)
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
                Text(title ?? workspaceTitle).font(.headline).opacity(OrbitHeaderMotion.fade(progress, from: 0.48, to: 1))
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


/// A single presentation value is read only by the header and its viewport.
/// Scrolling does not propagate a new environment value through every task row.
@Observable @MainActor
final class OrbitHeaderMotion {
    var offset: CGFloat = 0
    var progress: CGFloat { min(max(offset / 80, 0), 1) }
    var pullDown: CGFloat { max(0, -offset) }

    static func fade(_ value: CGFloat, from lower: CGFloat, to upper: CGFloat) -> CGFloat {
        let t = min(1, max(0, (value - lower) / (upper - lower)))
        return t * t * (3 - 2 * t)
    }
}

private struct OrbitScrollingHeader: ViewModifier {
    @State private var motion = OrbitHeaderMotion()
    func body(content: Content) -> some View {
        content.environment(\.orbitHeaderMotion, motion)
    }
}
extension View {
    func orbitScrollingHeader() -> some View { modifier(OrbitScrollingHeader()) }
}

private struct OrbitMainScrollObserver: ViewModifier {
    var enabled = true
    var followsCalendarGesture = false
    @Environment(\.orbitHeaderMotion) private var motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var handle = OrbitHeaderScrollHandle()
    func body(content: Content) -> some View {
        content.background {
            if enabled, let motion {
                OrbitHeaderScrollProbe(handle: handle, motion: motion,
                    calendar: followsCalendarGesture, reduceMotion: reduceMotion).allowsHitTesting(false)
            }
        }
        .onDisappear { handle.detach() }
    }
}
extension View {
    func orbitMainScrollObserver(enabled: Bool = true, followsCalendarGesture: Bool = false) -> some View {
        modifier(OrbitMainScrollObserver(enabled: enabled, followsCalendarGesture: followsCalendarGesture))
    }

    /// Empty screens retain elastic movement without artificial scrollable rows.
    func orbitEmptyScroll() -> some View {
        GeometryReader { geometry in
            ScrollView {
                self.frame(maxWidth: .infinity, minHeight: max(0, geometry.size.height - 88))
            }
            .contentMargins(.bottom, 88, for: .scrollContent)
            .scrollBounceBehavior(.always)
            .scrollIndicators(.hidden)
            .orbitMainScrollObserver()
        }
    }
}

/// Keep UIKit in charge of scrolling and observe touches passively without
/// replacing its delegate or preventing existing recognizers. A single
/// display link samples both the gesture and any header spring on screen frames.
@MainActor
private final class OrbitHeaderScrollHandle: NSObject {
    weak var scroll: UIScrollView?
    weak var motion: OrbitHeaderMotion?
    var calendar = false
    var reduceMotion = false
    private var observation: NSKeyValueObservation?
    private var displayLink: CADisplayLink?
    private var referenceTopInset: CGFloat = 0
    private var usesPan = false
    private var dragging = false
    private var touchOrigin: CGFloat = 0
    private var touchPosition: CGFloat = 0
    private var touchVelocity: CGFloat = 0
    private var touchTime: TimeInterval = 0
    private var touching = false
    private var touchObserver: OrbitHeaderTouchObserver?
    private var headerOrigin: CGFloat = 0
    private var spring: (start: CFTimeInterval, origin: CGFloat, velocity: CGFloat, target: CGFloat)?
    private var previousOffset: CGFloat = .nan
    private var restingFrames = 0

    private var contentFits: Bool {
        guard let scroll else { return false }
        return scroll.contentSize.height + scroll.adjustedContentInset.top
            + scroll.adjustedContentInset.bottom <= scroll.bounds.height + 1
    }

    func attach(_ scroll: UIScrollView) {
        guard self.scroll !== scroll else { return }
        detach()
        self.scroll = scroll
        referenceTopInset = scroll.adjustedContentInset.top
        let observer = OrbitHeaderTouchObserver(target: nil, action: nil)
        observer.cancelsTouchesInView = false
        observer.delaysTouchesBegan = false
        observer.delaysTouchesEnded = false
        observer.onTouch = { [weak self] phase, point, time in
            self?.touchChanged(phase, point: point, time: time)
        }
        scroll.addGestureRecognizer(observer)
        touchObserver = observer
        observation = scroll.observe(\.contentOffset) { [weak self] _, _ in
            // UIKit updates contentOffset on the main thread. Schedule drawing
            // on the display clock, outside the scroll/layout callback.
            MainActor.assumeIsolated { self?.startFrames() }
        }
        startFrames()
    }

    func detach() {
        if let touchObserver { scroll?.removeGestureRecognizer(touchObserver) }
        touchObserver = nil
        observation = nil
        displayLink?.invalidate()
        displayLink = nil
        scroll = nil
        spring = nil
        dragging = false
        touching = false
    }

    private func touchChanged(_ phase: UIGestureRecognizer.State, point: CGPoint, time: TimeInterval) {
        guard let scroll, let motion else { return }
        switch phase {
        case .began:
            spring = nil
            touching = true
            dragging = false
            usesPan = calendar || contentFits
            headerOrigin = motion.offset
            touchOrigin = point.y
            touchPosition = point.y
            touchTime = time
            touchVelocity = 0
            if abs(scroll.contentOffset.y + scroll.adjustedContentInset.top) < 1 {
                referenceTopInset = scroll.adjustedContentInset.top
            }
        case .changed:
            let elapsed = time - touchTime
            if elapsed > 0 { touchVelocity = (point.y - touchPosition) / elapsed }
            touchPosition = point.y
            touchTime = time
            dragging = scroll.isScrollEnabled && abs(point.y - touchOrigin) > 8
        case .ended, .cancelled, .failed:
            if dragging, usesPan, scroll.isScrollEnabled {
                samplePan()
                let velocity = time - touchTime < 0.12 && phase == .ended ? -touchVelocity : 0
                let projected = motion.offset + velocity * 0.10
                let target: CGFloat = motion.offset < 0 ? 0 : (projected < 40 ? 0 : 80)
                if reduceMotion { motion.offset = target; spring = nil }
                else {
                    let direction = target - motion.offset
                    let release = direction * velocity > 0 ? velocity : 0
                    let limit = min(600, 18 * abs(direction))
                    let bounded = min(limit, max(-limit, release))
                    spring = (CACurrentMediaTime(), motion.offset, bounded, target)
                }
            } else if usesPan, motion.offset != 0, motion.offset < 80 {
                let target: CGFloat = motion.offset < 40 ? 0 : 80
                if reduceMotion { motion.offset = target }
                else { spring = (CACurrentMediaTime(), motion.offset, 0, target) }
            }
            touching = false
            dragging = false
        default: break
        }
        startFrames()
    }

    private func startFrames() {
        restingFrames = 0
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func samplePan() {
        guard let scroll, let motion else { return }
        let raw = headerOrigin - (touchPosition - touchOrigin)
        if raw < 0, !calendar {
            // The same increasing resistance as a native short scroll surface.
            let distance = -raw
            let dimension = max(1, scroll.bounds.height)
            motion.offset = -min(120, (0.55 * distance * dimension) / (dimension + 0.55 * distance))
        } else { motion.offset = min(80, max(0, raw)) }
    }

    @objc private func frame(_ link: CADisplayLink) {
        guard let scroll, let motion else { detach(); return }
        if dragging, usesPan, scroll.isScrollEnabled {
            let native = scroll.panGestureRecognizer.state
            if native == .began || native == .changed { samplePan() }
        }
        if let spring {
            let t = max(0, link.timestamp - spring.start)
            let omega: CGFloat = 18
            let delta = spring.origin - spring.target
            let coefficient = spring.velocity + omega * delta
            let decay = exp(-omega * t)
            let position = spring.target + (delta + coefficient * t) * decay
            let velocity = (coefficient - omega * (delta + coefficient * t)) * decay
            motion.offset = min(80, position)
            if abs(position - spring.target) < 0.1 && abs(velocity) < 1 {
                motion.offset = spring.target
                self.spring = nil
            }
        }
        // Safe-area insets can finish laying out after this probe attaches.
        // A resting top boundary is the origin, never a rubber-band gesture.
        let boundary = scroll.contentOffset.y + scroll.adjustedContentInset.top
        if abs(boundary) < 0.1 { referenceTopInset = scroll.adjustedContentInset.top }
        let nativeOffset = scroll.contentOffset.y + referenceTopInset
        if !usesPan, !calendar {
            let elastic = scroll.isTracking || scroll.isDragging || scroll.isDecelerating
                ? min(0, boundary) : 0
            motion.offset = elastic < 0 ? max(-120, elastic) : min(80, max(0, nativeOffset))
        }
        let active = touching || dragging || scroll.isTracking || scroll.isDragging || scroll.isDecelerating || spring != nil
        if !active, abs(nativeOffset - previousOffset) < 0.1 { restingFrames += 1 }
        else { restingFrames = 0 }
        previousOffset = nativeOffset
        if restingFrames >= 2 {
            if !usesPan, !calendar, nativeOffset > 0.5, nativeOffset < 79.5 {
                let maximum = max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom + referenceTopInset)
                let target: CGFloat = nativeOffset < 40 || maximum < 80 ? 0 : 80
                scroll.setContentOffset(CGPoint(x: scroll.contentOffset.x, y: target - referenceTopInset), animated: !reduceMotion)
                restingFrames = 0
            } else {
                displayLink?.invalidate()
                displayLink = nil
            }
        }
    }
}

/// Passive touch sampling keeps the original window coordinates even when
/// UIScrollView resets its pan translation. This recognizer cannot prevent, or
/// be prevented by, task gestures, native scrolling, taps or horizontal swipes.
@MainActor
private final class OrbitHeaderTouchObserver: UIGestureRecognizer {
    var onTouch: ((UIGestureRecognizer.State, CGPoint, TimeInterval) -> Void)?
    private var origin: CGPoint?
    override func canPrevent(_ other: UIGestureRecognizer) -> Bool { false }
    override func canBePrevented(by other: UIGestureRecognizer) -> Bool { false }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard touches.count == 1, let touch = touches.first else { state = .failed; return }
        let point = touch.location(in: view?.window)
        origin = point
        onTouch?(.began, point, touch.timestamp)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let origin else { return }
        let point = touch.location(in: view?.window)
        if state == .possible {
            guard abs(point.y - origin.y) > 8 else { return }
            guard abs(point.y - origin.y) > abs(point.x - origin.x) else {
                onTouch?(.cancelled, point, touch.timestamp)
                state = .failed
                return
            }
            state = .began
        } else { state = .changed }
        onTouch?(.changed, point, touch.timestamp)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first else { return }
        onTouch?(.ended, touch.location(in: view?.window), touch.timestamp)
        state = state == .possible ? .failed : .ended
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        if let touch = touches.first { onTouch?(.cancelled, touch.location(in: view?.window), touch.timestamp) }
        state = .cancelled
    }
    override func reset() { super.reset(); origin = nil }
}

/// The marker is the background of the actual List/ScrollView, so match its
/// viewport in the nearest shared ancestor. No window-wide view lookup.
private struct OrbitHeaderScrollProbe: UIViewRepresentable {
    let handle: OrbitHeaderScrollHandle
    let motion: OrbitHeaderMotion?
    let calendar: Bool
    let reduceMotion: Bool
    final class ProbeView: UIView {
        var resolve: (() -> Void)?
        override func layoutSubviews() { super.layoutSubviews(); resolve?() }
        override func didMoveToWindow() { super.didMoveToWindow(); resolve?() }
    }
    func makeUIView(context: Context) -> ProbeView { ProbeView() }
    func updateUIView(_ view: ProbeView, context: Context) {
        handle.motion = motion
        handle.calendar = calendar
        handle.reduceMotion = reduceMotion
        view.resolve = { [weak view, weak handle] in
            DispatchQueue.main.async { [weak view, weak handle] in
                guard let view, let handle, view.window != nil else { return }
                if let scroll = handle.scroll, scroll.window === view.window { return }
                let frame = view.convert(view.bounds, to: nil)
                guard frame.width > 0, frame.height > 0 else { return }
                var root = view.superview
                while let candidateRoot = root {
                    if let scroll = matchingScroll(in: candidateRoot, frame: frame) {
                        handle.attach(scroll)
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

private struct OrbitHeaderMotionKey: EnvironmentKey { static let defaultValue: OrbitHeaderMotion? = nil }
extension EnvironmentValues {
    var orbitHeaderMotion: OrbitHeaderMotion? {
        get { self[OrbitHeaderMotionKey.self] }
        set { self[OrbitHeaderMotionKey.self] = newValue }
    }
}
