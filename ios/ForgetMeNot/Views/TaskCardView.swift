import SwiftUI
import UIKit

/// A task panel: mascot (vertically centered, transparent cutout) on the left; on the
/// right the title with the task type, the domain, the nudge speech bubble (middle), and
/// the live LED urgency meter. When the task is paused (inactive) the mascot sleeps.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let character: UIImage?

    private var asleep: Bool { task.status == .blocked }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            characterSlot
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.title.uppercased())
                        .font(WL.mono(16, .semibold)).tracking(1)
                        .foregroundStyle(WL.text).lineLimit(2)
                    Spacer(minLength: 6)
                    if !task.domain.isEmpty {
                        Text(task.domain.uppercased())
                            .font(WL.mono(9, .bold)).tracking(1).foregroundStyle(WL.muted)
                    }
                }
                if let nudge, !asleep {
                    SpeechBubble(text: nudge).transition(.opacity)
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
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlPanel(fill: WL.surface, border: WL.border)
        .opacity(asleep ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }

    private var characterSlot: some View {
        ZStack {
            Group {
                if let character {
                    Image(uiImage: character).resizable().scaledToFit()
                } else {
                    Image(systemName: "sparkle").font(.system(size: 18)).foregroundStyle(WL.muted.opacity(0.4))
                }
            }
            .opacity(asleep ? 0.5 : 1)
            .grayscale(asleep ? 0.9 : 0)
            if asleep {
                Image(systemName: "zzz")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(WL.muted)
                    .offset(x: 18, y: -16)
            }
        }
        .frame(width: 56, height: 56)
    }
}
