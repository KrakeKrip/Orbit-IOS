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
                    let atStart = point.x >= frame.maxX - 44 && point.y <= frame.minY + 44
                    let atEnd = point.x <= frame.minX + 44 && point.y >= frame.maxY - 44
                    if atStart || atEnd { return false }
                }
                return true
            }, creation: action))
    }
}

/// Native immediate boundary drag competes with the scroll pan before it wins.
/// Unlike a SwiftUI child drag, it is not cancelled by the card button's sheet.
struct TimelineResizeDrag: ViewModifier {
    let action: (UIGestureRecognizer.State, CGPoint, CGPoint) -> Void
    @State private var frame = CGRect.zero
    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
            .background(TimelineScrollResolver(minimumDuration: 0, exclusive: true,
                resolve: { _ in }, acceptsCreation: { frame.insetBy(dx: 0, dy: -12).contains($0) }, creation: action))
    }
}
