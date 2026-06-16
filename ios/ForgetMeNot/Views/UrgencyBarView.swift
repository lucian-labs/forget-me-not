import SwiftUI

/// Urgency as a square LED-style segment meter (waveloop motif). Fills left-to-right
/// with the cycle ratio, colored by tier; pulses once overdue.
struct UrgencyBarView: View {
    let ratio: Double
    private let segments = 28

    private var tier: UrgencyTier { Urgency.tier(for: ratio) }
    private var color: Color { WL.urgencyColor(tier) }
    private var clamped: Double { min(max(ratio, 0), 1) }

    @State private var pulse = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(Double(i) / Double(segments) < clamped ? color : Color.white.opacity(0.07))
            }
        }
        .frame(height: 5)
        .opacity(tier == .overdue && pulse ? 0.4 : 1)
        .onAppear { if tier == .overdue { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } } }
        .onChange(of: tier) { _, new in
            pulse = false
            if new == .overdue { withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true } }
        }
    }
}
