import SwiftUI
import UIKit

/// A task panel: left = its generated alien-animal mascot (mood reflects neglect),
/// right = title / domain / live LED meter / nudge. When `celebration` is set (just
/// after a swipe-reset), the card shows a success message in place and the mascot
/// flips to success mode, before the row resets and slides away.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let character: UIImage?
    let celebration: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            characterSlot(success: celebration != nil)
            if let celebration {
                successContent(celebration)
            } else {
                normalContent
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WL.surface)
        .overlay(Rectangle().stroke(celebration != nil ? WL.green : WL.border, lineWidth: 1))
        .animation(.easeInOut(duration: 0.3), value: celebration)
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }

    private var normalContent: some View {
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

    private func successContent(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message)
                .font(WL.mono(15, .bold)).tracking(1).foregroundStyle(WL.green)
                .fixedSize(horizontal: false, vertical: true)
            Text(task.title.uppercased())
                .font(WL.mono(10)).tracking(2).foregroundStyle(WL.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .transition(.opacity)
    }

    private func characterSlot(success: Bool) -> some View {
        Group {
            if let character {
                Image(uiImage: character).resizable().scaledToFill()
                    .overlay { if success { successBadge } }
            } else {
                ZStack {
                    Rectangle().fill(WL.bg)
                    Image(systemName: success ? "checkmark" : "sparkle")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(success ? WL.green : WL.muted.opacity(0.4))
                }
            }
        }
        .frame(width: 54, height: 54)
        .clipped()
        .overlay(Rectangle().stroke(success ? WL.green : WL.border, lineWidth: 1))
    }

    private var successBadge: some View {
        ZStack {
            WL.green.opacity(0.3)
            Image(systemName: "checkmark")
                .font(.system(size: 20, weight: .black)).foregroundStyle(WL.green)
        }
    }
}
