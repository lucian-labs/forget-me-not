import SwiftUI

struct UrgencyBar: View {
    let ratio: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.15))

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * min(CGFloat(ratio), 1))
                    .animation(.easeInOut(duration: 0.3), value: ratio)
            }
        }
        .frame(height: 4)
    }
}
