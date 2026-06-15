import Foundation

/// Watches active tasks and, as each crosses 80% / 90% / 100% of its cycle (once per
/// crossing per instance), generates an on-device nudge and surfaces it on the card.
/// Resetting a task starts a new instance, which re-arms all three thresholds.
@MainActor
@Observable
final class NudgeCoordinator {
    private let service = Nudges.service()
    private(set) var nudges: [String: String] = [:]   // taskId -> latest nudge text
    private var fired: Set<String> = []
    // First nudge at 70% so that after a reset (→ 0%) the prompt stays gone until 70%.
    private let thresholds: [Double] = [0.7, 0.9, 1.0]

    func evaluate(_ tasks: [TaskDTO], now: Date) {
        for task in tasks {
            guard let inst = task.instance else { continue }
            let ratio = Urgency.ratio(task, now: now)
            for threshold in thresholds where ratio >= threshold {
                let key = "\(task.id)|\(inst.startedAt.timeIntervalSince1970)|\(threshold)"
                guard !fired.contains(key) else { continue }
                fired.insert(key)
                let id = task.id
                Task { [weak self] in
                    guard let text = await self?.service.nudge(for: task) else { return }
                    self?.nudges[id] = text
                }
            }
        }
    }

    func nudge(for id: String) -> String? { nudges[id] }
    func clear(_ id: String) { nudges[id] = nil }
}
