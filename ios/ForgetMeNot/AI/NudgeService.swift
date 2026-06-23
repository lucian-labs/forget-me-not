import Foundation

/// Generates a short, concrete "unblock" nudge for a task — the smallest next
/// physical action, to beat activation-energy freeze ("the block is the decision,
/// not the doing"). On-device only.
protocol NudgeService: Sendable {
    /// intensity 0 = gentle (70/90%); higher = increasingly frantic as the task goes
    /// further past 100%.
    func nudge(for task: TaskDTO, intensity: Int) async -> String
}

/// Deterministic fallback used only when the on-device model is unavailable
/// (e.g. a device without Apple Intelligence). Never throws, never blocks.
enum StaticNudge {
    static func text(for task: TaskDTO, intensity: Int = 0) -> String {
        let base = task.prompts.randomElement() ?? "do the first 30 seconds of \(task.title)"
        switch intensity {
        case 0: return base
        case 1...3: return base.uppercased() + "."
        default: return base.uppercased() + "!! NOW."
        }
    }
}

struct StaticNudgeService: NudgeService {
    func nudge(for task: TaskDTO, intensity: Int) async -> String {
        StaticNudge.text(for: task, intensity: intensity)
    }
}

/// Resolves the best available nudge service. On iOS 26 + Apple Intelligence this is
/// the on-device Foundation Models service; otherwise the static fallback.
enum Nudges {
    static func service() -> any NudgeService {
        if #available(iOS 26.0, *) {
            return FoundationModelsNudgeService()
        }
        return StaticNudgeService()
    }
}
