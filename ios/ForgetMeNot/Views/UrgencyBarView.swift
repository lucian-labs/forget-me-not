import SwiftUI

/// Horizontal urgency bar: fills with the cycle ratio, colored by tier
/// (green → orange → red), pulsing once overdue.
struct UrgencyBarView: View {
    let ratio: Double

    private var tier: UrgencyTier { Urgency.tier(for: ratio) }

    private var color: Color {
        switch tier {
        case .calm: .green
        case .soon: .orange
        case .due, .overdue: .red
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * min(max(ratio, 0), 1))
            }
        }
        .frame(height: 6)
        .opacity(tier == .overdue ? 0.65 : 1)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                   value: tier == .overdue)
    }
}
