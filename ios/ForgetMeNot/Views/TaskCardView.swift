import SwiftUI
import UIKit

/// A task panel: left = its generated alien-animal mascot (mood reflects neglect),
/// right = title / domain / live LED meter / nudge. On swipe-reset (`celebration` set),
/// the content fades to 0 opacity — keeping the same height so nothing jumps — and a
/// success message is revealed behind it, before the row resets and slides away.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let character: UIImage?
    let celebration: String?

    var body: some View {
        ZStack {
            if let celebration {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(WL.green)
                    Text(celebration)
                        .font(WL.mono(15, .bold)).tracking(1).foregroundStyle(WL.green)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
            }
            content
                .opacity(celebration != nil ? 0 : 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WL.surface)
        .overlay(Rectangle().stroke(celebration != nil ? WL.green : WL.border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: celebration)
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
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
                    HStack(alignment: .top, spacing: 6) {
                        Text("▸").font(WL.mono(12, .bold)).foregroundStyle(WL.accent)
                        Text(nudge).font(WL.mono(12)).foregroundStyle(WL.cyan)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                    .transition(.opacity)
                }
            }
        }
    }

    private var characterSlot: some View {
        Group {
            if let character {
                Image(uiImage: character).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(WL.bg)
                    Image(systemName: "sparkle").font(.system(size: 15)).foregroundStyle(WL.muted.opacity(0.4))
                }
            }
        }
        .frame(width: 54, height: 54)
        .clipped()
        .overlay(Rectangle().stroke(WL.border, lineWidth: 1))
    }
}
