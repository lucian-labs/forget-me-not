import Foundation

/// Watches active tasks and fires on-device nudges as each crosses a series of
/// thresholds. Early on: 70% and 90% (gentle). Past 100% it keeps escalating — each
/// successive step is closer to the last (shrinking span) and more frantic in tone —
/// so a long-ignored task ends up urgently telling you what to do.
/// Resetting a task starts a new instance, which re-arms every step.
@MainActor
@Observable
final class NudgeCoordinator {
    private let service = Nudges.service()
    private(set) var nudges: [String: String] = [:]   // taskId -> latest nudge
    private var fired: Set<String> = []

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

    func evaluate(_ tasks: [TaskDTO], now: Date) {
        for task in tasks {
            guard let inst = task.instance else { continue }
            let ratio = Urgency.ratio(task, now: now)
            for step in Self.steps where ratio >= step.ratio {
                let key = "\(task.id)|\(inst.startedAt.timeIntervalSince1970)|\(step.ratio)"
                guard !fired.contains(key) else { continue }
                fired.insert(key)
                let id = task.id
                let intensity = step.intensity
                Task { [weak self] in
                    guard let text = await self?.service.nudge(for: task, intensity: intensity) else { return }
                    self?.nudges[id] = text
                }
            }
        }
    }

    func nudge(for id: String) -> String? { nudges[id] }
    func clear(_ id: String) { nudges[id] = nil }
}
