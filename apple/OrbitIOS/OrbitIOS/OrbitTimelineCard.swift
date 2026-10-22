import SwiftUI

/// One density policy for day and three-day events. Exact duration remains the caller's geometry.
struct OrbitTimelineCard: View {
    @Environment(\.orbitAppearance) private var appearance
    let title: String
    let range: String
    let completed: Bool
    let height: CGFloat
    let width: CGFloat
    let font: CGFloat
    let continuesFrom: Bool
    let continuesInto: Bool
    var selected = false
    private var cornerRadius: CGFloat { min(8, max(0, height / 2)) }
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(completed ? appearance.completedEventSurface : selected ? appearance.eventPreviewSurface : appearance.eventSurface)
            Rectangle().fill(completed ? appearance.secondaryText : Color.orbitAccent)
                .frame(width: 3)
            if height >= font + 8 {
                VStack(alignment: .leading, spacing: 3) {
                    Text((completed ? "✓ " : "") + title).font(.system(size: font, weight: .medium))
                        .foregroundStyle(completed ? appearance.secondaryText : appearance.eventText)
                        .lineLimit(height >= font * 3 + 14 ? 2 : 1)
                    if height >= font * 3 + 14 && width >= font * 8 {
                        Text(range).font(.caption.monospacedDigit()).lineLimit(1).foregroundStyle(appearance.secondaryText)
                    }
                }.padding(.leading, 10).padding(.trailing, 6).padding(.vertical, 4)
            }
            if continuesFrom {
                Image(systemName: "arrow.up.to.line").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.orbitAccent).frame(maxWidth: .infinity, alignment: .trailing).padding(3)
            }
            if continuesInto {
                VStack { Spacer(minLength: 0)
                    Image(systemName: "arrow.down.to.line").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.orbitAccent).frame(maxWidth: .infinity, alignment: .trailing).padding(3)
                }
            }
        }.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
