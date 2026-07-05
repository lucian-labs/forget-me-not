import SwiftUI

/// Gold-deco backdrop: warm near-black, a soft gilt bloom at the top, and a faint gold
/// grid that fades out — a quiet Art Deco field for the cards to sit on.
struct WLBackground: View {
    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            // Gilt bloom from the top center.
            RadialGradient(colors: [WL.accent.opacity(0.10), .clear],
                           center: .init(x: 0.5, y: -0.05), startRadius: 0, endRadius: 460)
                .ignoresSafeArea()
                .blendMode(.screen)
            GridPattern(spacing: 40)
                .stroke(WL.accent.opacity(0.06), lineWidth: 1)
                .ignoresSafeArea()
                .mask(
                    LinearGradient(colors: [.black, .black, .clear],
                                   startPoint: .top, endPoint: .bottom)
                )
        }
    }
}

/// A simple square grid of 1pt lines.
private struct GridPattern: Shape {
    var spacing: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        var x: CGFloat = 0
        while x <= rect.width {
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height)); x += spacing
        }
        var y: CGFloat = 0
        while y <= rect.height {
            p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: rect.width, y: y)); y += spacing
        }
        return p
    }
}
