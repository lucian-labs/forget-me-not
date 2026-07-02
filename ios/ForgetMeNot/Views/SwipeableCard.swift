import SwiftUI
import UIKit

/// One committed swipe direction on a card.
struct SwipeAction {
    let label: String
    let icon: String
    let color: Color
    /// true → the row is about to leave the list, so the card flies off with the throw;
    /// false → the action "stamps": haptic, color flash, and a tight spring home
    /// (recurring resets — the card stays, its meter just drops to zero).
    let removesRow: Bool
    let handler: () -> Void
}

/// Game-feel swipe: the card is locked 1:1 to the finger (no implicit animation on the
/// drag path), rubber-bands past the commit threshold, ticks a haptic the moment the
/// threshold is crossed, and on release either snaps home or commits with a spring that
/// inherits the throw's velocity. Input is a UIKit pan that only claims horizontal
/// gestures, so vertical scrolling never fights it (the old custom-drag problem).
struct SwipeableCard<Content: View>: View {
    let leading: SwipeAction    // drag right
    let trailing: SwipeAction   // drag left
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 320
    @State private var crossed = false
    @State private var flying = false
    @State private var flashColor: Color = .clear
    @State private var flashOpacity: Double = 0

    private let threshold: CGFloat = 92

    var body: some View {
        ZStack {
            underlay
            content()
                .overlay(Rectangle().fill(flashColor).opacity(flashOpacity).allowsHitTesting(false))
                .offset(x: offset)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
        .gesture(HorizontalPan(
            onChange: { t, _ in
                guard !flying else { return }
                offset = rubber(t)   // direct set — 1:1 tracking, no animation latency
                let over = abs(offset) >= threshold
                if over != crossed {
                    crossed = over
                    if over { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                }
            },
            onEnd: { _, v in
                guard !flying else { return }
                release(velocity: v)
            }
        ))
    }

    // MARK: - release physics

    private func release(velocity v: CGFloat) {
        let commit = abs(offset) >= threshold
            || (abs(v) > 900 && v * offset >= 0 && abs(offset) > 28)   // a real fling counts
        guard commit, offset != 0 else {
            snap(to: 0, velocity: v)
            crossed = false
            return
        }
        let action = offset > 0 ? leading : trailing
        if action.removesRow {
            flying = true
            let target = (offset > 0 ? 1 : -1) * (width + 80)
            snap(to: target, velocity: v)
            // Let the fly-off establish itself, then mutate state — the row's removal
            // transition + the list's spring handle the collapse.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { action.handler() }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            action.handler()                       // instant: the meter resets NOW
            flashColor = action.color
            flashOpacity = 0.4
            snap(to: 0, velocity: v, stiff: true)
            withAnimation(.easeOut(duration: 0.55)) { flashOpacity = 0 }
            crossed = false
        }
    }

    /// Spring that inherits the gesture's exit velocity (normalized per spring convention).
    private func snap(to target: CGFloat, velocity v: CGFloat, stiff: Bool = false) {
        let distance = target - offset
        let v0 = distance == 0 ? 0 : Double(v / distance)
        withAnimation(.interpolatingSpring(
            stiffness: stiff ? 480 : 340,
            damping: stiff ? 34 : 28,
            initialVelocity: v0
        )) { offset = target }
    }

    /// 1:1 up to the threshold, half-speed past it — reads as weight, not a wall.
    private func rubber(_ t: CGFloat) -> CGFloat {
        let a = abs(t)
        guard a > threshold else { return t }
        return (t < 0 ? -1 : 1) * (threshold + (a - threshold) * 0.5)
    }

    // MARK: - reveal layer

    private var underlay: some View {
        let progress = min(abs(offset) / threshold, 1)
        let active = offset > 0 ? leading : trailing
        return HStack {
            cue(leading, shown: offset > 0, progress: progress)
            Spacer()
            cue(trailing, shown: offset < 0, progress: progress)
        }
        .padding(.horizontal, 22)
        .frame(maxHeight: .infinity)
        .background(active.color.opacity(offset == 0 ? 0 : 0.10 + 0.35 * progress))
        .wlClip()
    }

    @ViewBuilder
    private func cue(_ action: SwipeAction, shown: Bool, progress: CGFloat) -> some View {
        VStack(spacing: 4) {
            Image(systemName: action.icon)
                .font(.system(size: 20, weight: .bold))
            Text(action.label)
                .font(WL.mono(9, .bold)).tracking(2)
        }
        .foregroundStyle(action.color)
        .scaleEffect(shown ? 0.7 + 0.45 * progress : 0.7)
        .opacity(shown ? Double(0.35 + 0.65 * progress) : 0)
    }
}

/// UIKit pan that claims ONLY horizontal gestures (velocity-angle check in shouldBegin),
/// so UIKit's arbitration gives vertical pans to the enclosing scroll view untouched.
/// Also accepts continuous trackpad scrolls, so Catalyst two-finger swipes work.
private struct HorizontalPan: UIGestureRecognizerRepresentable {
    var onChange: (CGFloat, CGFloat) -> Void   // translation.x, velocity.x
    var onEnd: (CGFloat, CGFloat) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.maximumNumberOfTouches = 1
        g.allowedScrollTypesMask = .continuous
        g.delegate = context.coordinator
        return g
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard let view = recognizer.view else { return }
        let t = recognizer.translation(in: view).x
        let v = recognizer.velocity(in: view).x
        switch recognizer.state {
        case .changed: onChange(t, v)
        case .ended, .cancelled, .failed: onEnd(t, v)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
            let vel = pan.velocity(in: view)
            return abs(vel.x) > abs(vel.y) * 1.4   // horizontal intent only
        }
    }
}
