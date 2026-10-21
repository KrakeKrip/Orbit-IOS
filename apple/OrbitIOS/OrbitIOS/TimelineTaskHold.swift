import SwiftUI
import UIKit

/// A native hold observes the enclosing scroll view without making its pan
/// wait for a SwiftUI sequenced zero-distance drag. A moving finger scrolls;
/// only a stationary hold enters task editing. Resize handles keep their own drag.
struct TimelineTaskHold: ViewModifier {
    let enabled: Bool
    var ignoresResizeHandles = false
    let action: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void
    @State private var frame = CGRect.zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .background(TimelineScrollResolver(resolve: { _ in }, acceptsCreation: { point in
                guard enabled, frame.contains(point) else { return false }
                if ignoresResizeHandles {
                    let atStart = abs(point.x - frame.maxX) < 20 && abs(point.y - frame.minY) < 20
                    let atEnd = abs(point.x - frame.minX) < 20 && abs(point.y - frame.maxY) < 20
                    if atStart || atEnd { return false }
                }
                return true
            }, creation: action))
    }
}
