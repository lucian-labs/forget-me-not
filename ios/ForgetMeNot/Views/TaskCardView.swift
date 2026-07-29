import SwiftUI
import UIKit

/// A task panel: icon (vertically centered, transparent cutout) on the left; on the
/// right the title with the task type, the domain, the nudge speech bubble (middle), and
/// the live LED urgency meter. When the task is paused (inactive) the icon sleeps.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let icon: UIImage?
    let symbol: String?
    // Web-parity card buttons (✓ / zz / ↓) — nil hides them (e.g. compact usages).
    var onDone: (() -> Void)? = nil
    var onSnooze: (() -> Void)? = nil
    var onRestart: (() -> Void)? = nil

    private var asleep: Bool { task.status == .blocked }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            iconSlot
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 8) {
                    Text(task.title.capitalized)
                        .font(WL.header(16, .semibold)).tracking(WL.trk(1))
                        .foregroundStyle(WL.text).lineLimit(2)
                    Spacer(minLength: 6)
                    actionCluster
                }
                if let nudge, !asleep {
                    SpeechBubble(text: nudge).transition(.opacity)
                }
                // 10s, not 1s: urgency creeps slowly, so per-second redraws of every card
                // were burning CPU continuously for an imperceptible change.
                TimelineView(.periodic(from: .now, by: 10)) { context in
                    let ratio = Urgency.ratio(task, now: context.date)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 10) {
                            UrgencyBarView(ratio: ratio)
                            Text("\(Int(min(ratio, 9.99) * 100))%")
                                .font(WL.mono(11, .bold))
                                .foregroundStyle(WL.urgencyColor(Urgency.tier(for: ratio)))
                                .frame(width: 46, alignment: .trailing)
                        }
                        HStack {
                            if !task.domain.isEmpty {
                                Text(WL.t(task.domain))
                                    .font(WL.body(8, .bold)).tracking(WL.trk(1))
                                    .foregroundStyle(WL.muted.opacity(0.75))
                            }
                            Spacer()
                            if let clock = Urgency.clockLabel(task, now: context.date) {
                                Text(clock)
                                    .font(WL.body(8, .semibold)).tracking(WL.trk(1))
                                    .foregroundStyle(WL.muted.opacity(0.75))
                            }
                        }
                    }
                }
            }
        }
        .padding(WL.pad(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlPanel(fill: WL.surface, border: WL.border)
        .opacity(asleep ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.25), value: nudge)
    }

    /// Web-parity quick actions: ✓ done, zz snooze, ↓ restart quietly (recurring only).
    @ViewBuilder private var actionCluster: some View {
        HStack(spacing: 6) {
            if let onDone {
                cardButton("checkmark", tint: WL.green, action: onDone)
                    .accessibilityLabel("Done")
            }
            if task.recurring, let onSnooze {
                cardButton(text: "zz", tint: WL.gold, action: onSnooze)
                    .accessibilityLabel("Snooze")
            }
            if task.recurring, let onRestart {
                cardButton("arrow.down", tint: WL.muted, action: onRestart)
                    .accessibilityLabel("Restart timer quietly")
            }
        }
    }

    private func cardButton(_ systemName: String? = nil, text: String? = nil,
                            tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if let systemName {
                    Image(systemName: systemName).font(.system(size: 11, weight: .bold))
                } else {
                    Text(text ?? "").font(WL.body(10, .bold))
                }
            }
            .foregroundStyle(tint.opacity(0.9))
            .frame(width: 28, height: 28)
            .background(WL.bg.opacity(0.5))
            .wlStroke(WL.line)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconSlot: some View {
        ZStack {
            Group {
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(WL.accent)
                } else if let icon {
                    Image(uiImage: icon).resizable().scaledToFit()
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
