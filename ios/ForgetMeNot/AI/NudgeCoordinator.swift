import Foundation

/// Renders each active task's nudge ("quote") from its CURRENT urgency when the app opens
/// — not on a timer. The tier a task sits in picks the nudge: 70% and 90% (gentle), then
/// from 100% upward the tone climbs and gets more frantic. Below 70% there's no quote.
/// Reconciling on open keeps the quote in lockstep with the icon, which renders the
/// same way; resetting a task drops to a new instance at ~0%, clearing the quote.
@MainActor
@Observable
final class NudgeCoordinator {
    private let service = Nudges.service()
    private(set) var nudges: [String: String] = [:]   // taskId -> current nudge
    private var rendered: [String: String] = [:]       // taskId -> tier key already rendered
    private var generating: Set<String> = []

    /// (ratio, intensity). 0.7/0.9 gentle, then from 100% upward with spans that shrink
    /// (0.10, 0.085, 0.07, …) and intensity that climbs.
    private static let steps: [(ratio: Double, intensity: Int)] = {
        var list: [(Double, Int)] = [(0.7, 0), (0.9, 0)]
        var t = 1.0, gap = 0.1, level = 1
        for _ in 0..<14 {
            list.append((t, level))
            t += gap
            gap = max(0.02, gap - 0.015)
            level += 1
        }
        return list
    }()

    /// Reconcile every active task's quote to its current tier. Generates only when the
    /// tier changed since the last render (or nothing is shown yet).
    func evaluate(_ tasks: [TaskDTO], now: Date) {
        for task in tasks {
            guard let inst = task.instance else { clearState(task.id); continue }
            let ratio = Urgency.ratio(task, now: now)
            guard let step = Self.steps.last(where: { ratio >= $0.ratio }) else {
                clearState(task.id); continue   // below the first threshold → no quote
            }
            let key = "\(inst.startedAt.timeIntervalSince1970)|\(step.ratio)"
            if rendered[task.id] == key, nudges[task.id] != nil { continue }
            if generating.contains(task.id) { continue }
            rendered[task.id] = key
            generating.insert(task.id)
            let id = task.id, intensity = step.intensity, renderKey = key
            Task { [weak self] in
                guard let self else { return }
                let text = await self.service.nudge(for: task, intensity: intensity)
                self.generating.remove(id)
                guard self.rendered[id] == renderKey else { return }   // reset/superseded
                self.nudges[id] = text
            }
        }
    }

    func nudge(for id: String) -> String? { nudges[id] }
    func clear(_ id: String) { clearState(id) }

    private func clearState(_ id: String) {
        nudges[id] = nil
        rendered[id] = nil
        generating.remove(id)
    }
}
