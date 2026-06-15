import SwiftUI

/// The waveloop backdrop: near-black indigo, a faint top accent bloom, and a 40pt
/// grid texture that fades out from the top.
struct WLBackground: View {
    var body: some View {
        ZStack {
            WL.bg.ignoresSafeArea()
            LinearGradient(
                colors: [WL.accent.opacity(0.10), .clear],
                startPoint: .top, endPoint: .center
            )
            .ignoresSafeArea()
            GridPattern(spacing: 40)
                .stroke(Color.white.opacity(0.035), lineWidth: 1)
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
