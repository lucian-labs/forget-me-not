import SwiftUI

/// A single task as a square waveloop panel: uppercase monospaced title, overline
/// domain, a live LED urgency meter with a % readout, and the on-device nudge (when
/// fired). Only the meter ticks (its own TimelineView) so the parent list stays still
/// and swipe-to-reset stays smooth.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title.uppercased())
                    .font(WL.mono(16, .semibold))
                    .tracking(1)
                    .foregroundStyle(WL.text)
                    .lineLimit(2)
                Spacer(minLength: 4)
                if task.recurring {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WL.muted)
                }
            }

            if !task.domain.isEmpty {
                Text(task.domain.uppercased())
                    .font(WL.mono(10))
                    .tracking(2)
                    .foregroundStyle(WL.muted)
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                let ratio = Urgency.ratio(task, now: context.date)
                HStack(spacing: 10) {
                    UrgencyBarView(ratio: ratio)
                    Text("\(Int(min(ratio, 9.99) * 100))%")
                        .font(WL.mono(11, .bold))
                        .foregroundStyle(WL.urgencyColor(Urgency.tier(for: ratio)))
                        .frame(width: 46, alignment: .trailing)
                }
            }

            if let nudge {
                HStack(alignment: .top, spacing: 6) {
                    Text("▸")
                        .font(WL.mono(12, .bold))
                        .foregroundStyle(WL.accent)
                    Text(nudge)
                        .font(WL.mono(12))
                        .foregroundStyle(WL.cyan)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WL.surface)
        .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }
}
