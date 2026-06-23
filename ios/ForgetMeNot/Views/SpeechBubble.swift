import SwiftUI

/// A rounded speech bubble with a small tail on the left (pointing at the icon).
struct BubbleShape: Shape {
    static let defaultTail: CGFloat = 7
    var radius: CGFloat
    var tail: CGFloat = BubbleShape.defaultTail

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r = min(radius, rect.height / 2)
        let body = CGRect(x: rect.minX + tail, y: rect.minY,
                          width: max(0, rect.width - tail), height: rect.height)
        p.addRoundedRect(in: body, cornerSize: CGSize(width: r, height: r))
        let midY = rect.midY
        p.move(to: CGPoint(x: rect.minX, y: midY))
        p.addLine(to: CGPoint(x: rect.minX + tail + 1, y: midY - 7))
        p.addLine(to: CGPoint(x: rect.minX + tail + 1, y: midY + 7))
        p.closeSubpath()
        return p
    }
}

/// The creature's nudge, shown as a little speech bubble.
struct SpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(WL.mono(12))
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.leading, 15)
            .padding(.trailing, 11)
            .padding(.vertical, 8)
            .background(WL.cyan, in: BubbleShape(radius: max(8, WL.radius)))
            .fixedSize(horizontal: false, vertical: true)
            // Pull left by the tail width so the bubble BODY left-aligns with the title/bar
            // and the tail pokes into the gap toward the icon.
            .offset(x: -BubbleShape.defaultTail)
    }
}
