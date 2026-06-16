import SwiftUI
import UIKit

/// A task panel that physically slides right to reveal a recessed "pocket" behind it,
/// with a snack for the creature at the pocket's depth. Drag past the threshold and
/// release to drop the snack (reset); release short and it springs back. Tap opens
/// detail. Vertical scrolling is preserved via `simultaneousGesture`.
struct TaskCardView: View {
    let task: TaskDTO
    let nudge: String?
    let character: UIImage?
    let onTap: () -> Void
    let onReset: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var committing = false

    private let maxOpen: CGFloat = 130
    private let threshold: CGFloat = 72

    var body: some View {
        ZStack(alignment: .leading) {
            pocket
            front
                .offset(x: dragX)
                .simultaneousGesture(drag)
                .onTapGesture {
                    if dragX != 0 {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { dragX = 0 }
                    } else {
                        onTap()
                    }
                }
        }
        .wlClip()
    }

    // MARK: front

    private var front: some View {
        HStack(alignment: .top, spacing: 10) {
            characterSlot
            rightColumn
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .wlPanel(fill: WL.surface, border: WL.border)
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(task.title.uppercased())
                    .font(WL.mono(16, .semibold)).tracking(1)
                    .foregroundStyle(WL.text).lineLimit(2)
                Spacer(minLength: 4)
                if task.recurring {
                    Image(systemName: "repeat").font(.system(size: 10, weight: .bold)).foregroundStyle(WL.muted)
                }
            }
            if !task.domain.isEmpty {
                Text(task.domain.uppercased()).font(WL.mono(10)).tracking(2).foregroundStyle(WL.muted)
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
                SpeechBubble(text: nudge).transition(.opacity)
            }
        }
    }

    private var characterSlot: some View {
        Group {
            if let character {
                Image(uiImage: character).resizable().scaledToFit()
            } else {
                Image(systemName: "sparkle").font(.system(size: 18)).foregroundStyle(WL.muted.opacity(0.4))
            }
        }
        .frame(width: 56, height: 56)
    }

    // MARK: pocket

    private var pocket: some View {
        let progress = Double(min(1, max(0, dragX / threshold)))
        return ZStack(alignment: .leading) {
            WL.bg
            LinearGradient(colors: [Color.black.opacity(0.30), .clear], startPoint: .leading, endPoint: .center)
            HStack {
                VStack(spacing: 4) {
                    Image(systemName: "fish.fill").font(.system(size: 22)).foregroundStyle(WL.green)
                    Text("SNACK").font(WL.mono(8, .bold)).tracking(1).foregroundStyle(WL.green)
                }
                .padding(.leading, 24)
                .opacity(progress)
                .scaleEffect(0.6 + 0.4 * progress)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: drag

    private var drag: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { v in
                guard !committing else { return }
                if v.translation.width > 0, abs(v.translation.width) > abs(v.translation.height) {
                    let raw = v.translation.width
                    dragX = raw < maxOpen ? raw : maxOpen + (raw - maxOpen) * 0.2   // rubber-band
                }
            }
            .onEnded { _ in
                guard !committing else { return }
                if dragX >= threshold {
                    commit()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { dragX = 0 }
                }
            }
    }

    private func commit() {
        committing = true
        withAnimation(.easeOut(duration: 0.22)) { dragX = maxOpen }   // snap fully open — snack delivered
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            onReset()                                                  // reset → rows slide up
            withAnimation(.easeInOut(duration: 0.3)) { dragX = 0 }
            committing = false
        }
    }
}
