import SwiftUI
import UIKit

/// A task panel: left = its mascot (transparent cutout, floats), right = title / domain /
/// live LED meter / a speech bubble with the creature's nudge. Corner radius follows the
/// theme. On swipe-reset the content fades to reveal a success message behind it (constant
/// height), then the row resets and slides away.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let character: UIImage?
    let celebration: String?
    let messageFaded: Bool

    var body: some View {
        ZStack {
            if let celebration {
                HStack(spacing: 0) {
                    Text(celebration)
                        .font(WL.mono(15, .bold)).tracking(1).foregroundStyle(WL.green)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .opacity(messageFaded ? 0 : 1)
            }
            content.opacity(celebration != nil ? 0 : 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlPanel(fill: WL.surface, border: celebration != nil && !messageFaded ? WL.green : WL.border)
        .animation(.easeInOut(duration: 0.3), value: celebration)
        .animation(.easeInOut(duration: 0.3), value: messageFaded)
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            characterSlot

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(task.title.uppercased())
                        .font(WL.mono(16, .semibold)).tracking(1)
                        .foregroundStyle(WL.text).lineLimit(2)
                    Spacer(minLength: 4)
                    if task.recurring {
                        Image(systemName: "repeat")
                            .font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                    }
                }

                if !task.domain.isEmpty {
                    Text(task.domain.uppercased())
                        .font(WL.mono(10)).tracking(2).foregroundStyle(WL.muted)
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
                    SpeechBubble(text: nudge)
                        .transition(.opacity)
                }
            }
        }
    }

    private var characterSlot: some View {
        Group {
            if let character {
                Image(uiImage: character).resizable().scaledToFit()
            } else {
                Image(systemName: "sparkle")
                    .font(.system(size: 18)).foregroundStyle(WL.muted.opacity(0.4))
            }
        }
        .frame(width: 56, height: 56)
    }
}
